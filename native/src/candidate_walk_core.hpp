#pragma once
#include <array>
#include <cstddef>
#include <vector>

namespace road {
struct CandidateWalk {
    std::vector<int> cells,nodes;
    std::vector<std::array<int,2>> ranges;
    int erased_steps=0;
};
// Scratch positions are reused across samples. Reset only touched cells, so
// each walk costs O(length), rather than clearing the whole map each time.
inline bool normalize_candidate_walk(const std::vector<int> &original,const std::vector<int> &node_at,
                                     std::vector<int> &positions,CandidateWalk &out) {
    out=CandidateWalk{};
    for(int cell:original) {
        if(cell<0 || std::size_t(cell)>=positions.size()) {
            for(int retained:out.cells) positions[retained]=-1;
            return false;
        }
        int previous=positions[cell];
        if(previous>=0) {
            while(out.cells.size()>std::size_t(previous+1)) {positions[out.cells.back()]=-1;out.cells.pop_back();}
        } else {positions[cell]=int(out.cells.size());out.cells.push_back(cell);}
    }
    for(int cell:out.cells) positions[cell]=-1;
    if(out.cells.empty() || node_at[out.cells.front()]<0 || node_at[out.cells.back()]<0) return false;
    int begin=-1;
    for(std::size_t i=0;i<out.cells.size();++i) {
        int node=node_at[out.cells[i]];if(node<0) continue;
        out.nodes.push_back(node);
        if(begin>=0) out.ranges.push_back({begin,int(i)});
        begin=int(i);
    }
    out.erased_steps=int(original.size()-out.cells.size());return true;
}
struct CandidateSequenceHash {
    std::size_t operator()(const std::vector<int> &values) const {
        std::size_t hash=values.size();
        for(int value:values) hash^=std::size_t(value)+std::size_t(0x9e3779b9)+(hash<<6)+(hash>>2);
        return hash;
    }
};
}
