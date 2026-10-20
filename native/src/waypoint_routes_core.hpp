#pragma once
#include "route_choices_core.hpp"

namespace road::waypoint_detail {
using Adjacency=std::vector<std::vector<std::pair<int,int>>>;
struct Tree { std::vector<double> distance;std::vector<int> parent,via; };
struct Walk { std::vector<int> nodes,edges;double score=0; };

// Reverse adjacency keeps the original directed edge cost. Reuse the two
// unrestricted trees for every waypoint; only conflicting joins need repairs.
inline Tree shortest(const RouteChoices &g,const Adjacency &adjacent,int root,
                     const std::vector<bool> &blocked,int target,int &searches,int &expanded) {
    ++searches;Tree tree;
    tree.distance.assign(g.vertices,std::numeric_limits<double>::infinity());
    tree.parent.assign(g.vertices,-1);tree.via.assign(g.vertices,-1);
    if(blocked[root]) return tree;
    using Item=std::pair<double,int>;
    std::priority_queue<Item,std::vector<Item>,std::greater<Item>> queue;
    tree.distance[root]=0;queue.push({0,root});
    while(!queue.empty()) {
        auto [distance,a]=queue.top();queue.pop();if(distance!=tree.distance[a]) continue;
        ++expanded;if(a==target) break;
        for(auto [id,b]:adjacent[a]) if(!blocked[b]) {
            double next=distance+g.edges[id].cost;
            if(std::isfinite(next) && next>distance && next<tree.distance[b]) {
                tree.distance[b]=next;tree.parent[b]=a;tree.via[b]=id;queue.push({next,b});
            }
        }
    }
    return tree;
}

inline Walk trace(const Tree &tree,int root,int at,bool reverse) {
    Walk walk;if(!std::isfinite(tree.distance[at])) return walk;
    walk.score=tree.distance[at];walk.nodes.push_back(at);
    while(at!=root) {walk.edges.push_back(tree.via[at]);at=tree.parent[at];walk.nodes.push_back(at);}
    if(!reverse) {std::reverse(walk.nodes.begin(),walk.nodes.end());std::reverse(walk.edges.begin(),walk.edges.end());}
    return walk;
}

inline Walk join(const Walk &prefix,int edge,const Walk &suffix,int vertices,double cost) {
    if(prefix.nodes.empty() || suffix.nodes.empty()) return {};
    std::vector<bool> seen(vertices,false);
    for(int node:prefix.nodes) seen[node]=true;
    for(int node:suffix.nodes) {if(seen[node]) return {};seen[node]=true;}
    Walk result=prefix;
    result.edges.push_back(edge);result.edges.insert(result.edges.end(),suffix.edges.begin(),suffix.edges.end());
    result.nodes.insert(result.nodes.end(),suffix.nodes.begin(),suffix.nodes.end());
    result.score=prefix.score+cost+suffix.score;
    return std::isfinite(result.score) ? result : Walk{};
}

// Independent shortest legs are optimal when disjoint. If they overlap,
// lock one leg and reroute the other, trying both orders. This bounded repair
// never repeats a vertex, but is not an exhaustive constrained-path solver.
inline Walk through(const RouteChoices &g,const Adjacency &forward,const Adjacency &reverse,
                    const Tree &from_start,const Tree &to_goal,int start,int goal,
                    int id,int from,int to,int &searches,int &expanded) {
    if(from==goal || to==start || from==to) return {};
    auto prefix=trace(from_start,start,from,false),suffix=trace(to_goal,goal,to,true);
    Walk best=join(prefix,id,suffix,g.vertices,g.edges[id].cost);
    if(!best.nodes.empty() || prefix.nodes.empty() || suffix.nodes.empty()) return best;
    auto keep=[&](Walk candidate) {
        if(!candidate.nodes.empty() && (best.nodes.empty() || candidate.score<best.score)) best=std::move(candidate);
    };
    std::vector<bool> blocked(g.vertices,false);
    if(std::find(prefix.nodes.begin(),prefix.nodes.end(),to)!=prefix.nodes.end()) {
        blocked[to]=true;
        prefix=trace(shortest(g,forward,start,blocked,from,searches,expanded),start,from,false);
    }
    if(!prefix.nodes.empty()) {
        std::fill(blocked.begin(),blocked.end(),false);for(int node:prefix.nodes) blocked[node]=true;
        auto tail=trace(shortest(g,forward,to,blocked,goal,searches,expanded),to,goal,false);
        keep(join(prefix,id,tail,g.vertices,g.edges[id].cost));
    }
    std::fill(blocked.begin(),blocked.end(),false);
    if(std::find(suffix.nodes.begin(),suffix.nodes.end(),from)!=suffix.nodes.end()) {
        blocked[from]=true;
        suffix=trace(shortest(g,reverse,goal,blocked,to,searches,expanded),goal,to,true);
    }
    if(!suffix.nodes.empty()) {
        std::fill(blocked.begin(),blocked.end(),false);for(int node:suffix.nodes) blocked[node]=true;
        auto head=trace(shortest(g,forward,start,blocked,from,searches,expanded),start,from,false);
        keep(join(head,id,suffix,g.vertices,g.edges[id].cost));
    }
    return best;
}
}
