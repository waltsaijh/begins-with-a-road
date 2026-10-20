#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <queue>
#include <vector>

namespace road {
inline bool cost_equal(double a,double b) {
    return a==b || (std::isfinite(a) && std::isfinite(b) && std::abs(a-b)<=1e-10*std::max({1.0,std::abs(a),std::abs(b)}));
}
struct CostField {std::vector<double> distance;std::vector<int> order;};
// Entering v costs costs[v]. Reverse search must instead charge costs[u].
inline CostField tile_cost_field(const std::vector<std::vector<int>> &adjacent,const std::vector<double> &costs,
                                int source,bool reverse=false,const std::vector<bool> &stops={}) {
    CostField result;result.distance.assign(costs.size(),-1);result.distance[source]=0;
    bool uniform=std::all_of(costs.begin(),costs.end(),[&](double c){return c==costs[0];});
    if(uniform) {
        result.order.push_back(source);
        for(size_t head=0;head<result.order.size();++head) {
            int a=result.order[head];if(!stops.empty() && stops[a] && a!=source) continue;
            for(int b:adjacent[a]) if(result.distance[b]<0) {result.distance[b]=result.distance[a]+costs[b];result.order.push_back(b);}
        }
    } else {
        using Item=std::pair<double,int>;
        std::priority_queue<Item,std::vector<Item>,std::greater<Item>> queue;queue.push({0,source});
        while(!queue.empty()) {
            auto item=queue.top();queue.pop();int a=item.second;
            if(item.first!=result.distance[a]) continue;
            result.order.push_back(a);if(!stops.empty() && stops[a] && a!=source) continue;
            for(int b:adjacent[a]) {
                double candidate=item.first+(reverse ? costs[a] : costs[b]);
                if(result.distance[b]<0 || candidate<result.distance[b]) {result.distance[b]=candidate;queue.push({candidate,b});}
            }
        }
    }
    return result;
}
inline bool cost_step(double from,double to,double cost) {return from>=0 && to>from && cost_equal(from+cost,to);}
}
