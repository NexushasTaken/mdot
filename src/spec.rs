#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct LinkClause {
    pub src: String,
    pub dst: String,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Spec {
    pub link_clauses: Vec<LinkClause>,
}
