#pragma once

#include <string>
#include <vector>

struct LinkClause {
  std::string m_src;
  std::string m_dst;
};

struct Spec {
  std::vector<LinkClause> link_clauses;
};
