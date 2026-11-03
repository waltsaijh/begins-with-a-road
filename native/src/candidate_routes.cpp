#include "route_planner.hpp"
#include "candidate_walk_core.hpp"
#include "portal_routes_pack.hpp"
#include <chrono>
#include <unordered_set>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
using namespace godot;
namespace {
Dictionary failure(const char *message) {Dictionary result;result["valid"]=false;result["error"]=message;return result;}
}

Dictionary RoadRoutePlanner::candidate_representatives(const String &profile,int64_t samples,Dictionary segment_ids) const {
    auto found=profiles.find(profile.utf8().get_data());
    if(found==profiles.end() || !found->second.plan.valid) return failure("missing_candidate_source");
    if(samples<1 || samples>256) return failure("local_samples_out_of_range");
    std::vector<int> node_at(physical.cells.size(),-1),positions(physical.cells.size(),-1),raw;
    for(size_t i=0;i<physical.nodes.size();++i) node_at[physical.nodes[i].cell]=int(i);
    std::unordered_set<std::vector<int>,road::CandidateSequenceHash> raw_seen,seen;
    int64_t normalization_us=0,raw_samples=0,erased_routes=0,erased_steps=0;
    Array entries;
    for(size_t index=0;index<found->second.plan.routes.size();++index) for(int variant=0;variant<samples;++variant) {
        double score=0;int selected=-1;
        if(!sample_cells(found->second,uint64_t(variant),index,raw,score,selected) || !raw_seen.insert(raw).second) continue;
        auto began=std::chrono::steady_clock::now();road::CandidateWalk normalized;
        if(!road::normalize_candidate_walk(raw,node_at,positions,normalized)) return failure("invalid_candidate_walk");
        // Preserve first-seen segment IDs, including segments of candidates
        // subsequently removed as duplicates, exactly as the script pipeline.
        PackedInt32Array indices=pack_route_values<PackedInt32Array>(normalized.cells),edges;
        Array ranges;
        for(auto span:normalized.ranges) {
            std::vector<int> cells(normalized.cells.begin()+span[0],normalized.cells.begin()+span[1]+1);
            PackedInt32Array key=pack_route_values<PackedInt32Array>(cells);
            if(!segment_ids.has(key)) segment_ids[key]=segment_ids.size();
            edges.push_back(int(segment_ids[key]));ranges.push_back(Vector2i(span[0],span[1]));
        }
        PackedVector2Array cells;cells.resize(normalized.cells.size());auto *write=cells.ptrw();
        for(size_t i=0;i<normalized.cells.size();++i) {const auto &tile=physical.cells[normalized.cells[i]];write[i]=Vector2(tile.x,tile.y);}
        Dictionary route;route["cells"]=cells;route["nodes"]=pack_route_values<PackedInt32Array>(normalized.nodes);
        route["edges"]=edges;route["length"]=int64_t(normalized.cells.size())-1;route["route_index"]=int64_t(index);route["candidate_variant"]=variant;
        normalization_us+=std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-began).count();
        ++raw_samples;if(normalized.erased_steps) {++erased_routes;erased_steps+=normalized.erased_steps;}
        if(!seen.insert(normalized.cells).second) continue;
        Dictionary entry;entry["route"]=route;entry["indices"]=indices;entry["ranges"]=ranges;entries.push_back(entry);
    }
    Dictionary normalization;normalization["normalization_us"]=normalization_us;normalization["raw_samples"]=raw_samples;
    normalization["loop_erased_routes"]=erased_routes;normalization["loop_erased_steps"]=erased_steps;
    Dictionary result;result["valid"]=true;result["entries"]=entries;result["normalization"]=normalization;return result;
}

Dictionary RoadRoutePlanner::search_costs(const PackedFloat64Array &weights) {
    double minimum=std::numeric_limits<double>::infinity();
    for(int64_t i=0;i<weights.size();++i) {if(!std::isfinite(weights[i])) return failure("候選探索成本必須為正有限數值");minimum=std::min(minimum,weights[i]);}
    double shift=minimum<=0 ? 1.0-minimum : 0;bool neutral=true;
    PackedFloat64Array costs;costs.resize(weights.size());auto *write=costs.ptrw();
    for(int64_t i=0;i<weights.size();++i) {
        double cost=weights[i]+shift;if(!std::isfinite(cost) || cost<=0) return failure("候選探索成本必須為正有限數值");
        write[i]=cost;neutral=neutral && cost==1.0;
    }
    Dictionary result;result["valid"]=true;result["costs"]=costs;result["neutral"]=neutral;return result;
}

Dictionary RoadRoutePlanner::build_distribution(const PackedFloat64Array &scores,double temperature,int64_t selection) {
    if(selection!=0 && selection!=1) return failure("未知的路線分配模式");
    if(selection==1 && (std::isnan(temperature) || temperature<=0)) return failure("路線 temperature 必須為正，可使用 INF 表示等機率");
    double best=std::numeric_limits<double>::infinity();
    for(int64_t i=0;i<scores.size();++i) {if(!std::isfinite(scores[i])) return failure("路線評分必須為有限數值");best=std::min(best,scores[i]);}
    PackedFloat64Array probabilities,cdf;probabilities.resize(scores.size());cdf.resize(scores.size());
    auto *p=probabilities.ptrw();auto *c=cdf.ptrw();double total=0,cumulative=0;
    for(int64_t i=0;i<scores.size();++i) {p[i]=selection==0 || std::isinf(temperature) ? 1.0 : std::exp(-(scores[i]-best)/temperature);total+=p[i];}
    for(int64_t i=0;i<scores.size();++i) {cumulative+=p[i];p[i]/=total;c[i]=cumulative/total;}
    Dictionary result;result["valid"]=true;result["probabilities"]=probabilities;result["cdf"]=cdf;return result;
}

Dictionary RoadRoutePlanner::rank_candidates(const Array &entries,const PackedFloat64Array &weights,double threshold,double temperature,int64_t selection) {
    if(std::isnan(threshold) || threshold<0) return failure("候選門檻必須非負，可使用 INF");
    for(int64_t i=0;i<weights.size();++i) if(!std::isfinite(weights[i])) return failure("候選路線總評分超出有限範圍");
    std::unordered_set<std::vector<int>,road::CandidateSequenceHash> seen;
    Array scored;std::vector<double> scores;double best=std::numeric_limits<double>::infinity();
    for(int64_t i=0;i<entries.size();++i) {
        Dictionary entry=entries[i];PackedInt32Array indices=entry["indices"];
        std::vector<int> sequence;if(!indices.is_empty()) sequence.assign(indices.ptr(),indices.ptr()+indices.size());
        if(!seen.insert(sequence).second) continue;
        double score=0;
        for(size_t j=0;j<sequence.size();++j) {
            int cell=sequence[j];if(cell<0 || cell>=weights.size()) return failure("candidate_tile_index_out_of_range");
            if(j) score+=weights[cell];
        }
        if(!std::isfinite(score)) return failure("候選路線總評分超出有限範圍");
        best=std::min(best,score);scored.push_back(entry);scores.push_back(score);
    }
    Array accepted;PackedFloat64Array accepted_scores;
    for(size_t i=0;i<scores.size();++i) {
        if(!std::isinf(threshold) && scores[i]-best>=threshold) continue;
        Dictionary selected;selected["entry"]=scored[i];selected["score"]=scores[i];accepted.push_back(selected);accepted_scores.push_back(scores[i]);
    }
    Dictionary distribution=build_distribution(accepted_scores,temperature,selection);if(!bool(distribution["valid"])) return distribution;
    Dictionary result;result["valid"]=true;result["routes"]=accepted;result["score"]=best;
    result["candidate_routes"]=int64_t(scored.size());result["distribution"]=distribution;return result;
}

PackedInt32Array RoadRoutePlanner::allocate_indices(const PackedFloat64Array &cdf,int64_t total) {
    PackedInt32Array indices;if(total<=0 || total>INT32_MAX || cdf.is_empty()) return indices;
    indices.resize(total);auto *write=indices.ptrw();
    for(int64_t i=0;i<total;++i) write[i]=int(std::upper_bound(cdf.ptr(),cdf.ptr()+cdf.size(),double(i)/double(total))-cdf.ptr());
    return indices;
}
