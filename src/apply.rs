use crate::common::create_symlink;
use crate::error::LinkError;
use crate::link::{plan_link, LinkPlan};
use std::fs;
use std::path::Path;

pub fn apply_link(src: &Path, dst: &Path) -> Result<LinkPlan, LinkError> {
    if src.is_relative() {
        return Err(LinkError::new(src, "must be absolute path"));
    }
    if dst.is_relative() {
        return Err(LinkError::new(dst, "must be absolute path"));
    }

    // C++: `if (plan_result) { ... } return plan_result;`. `?` returns the error early,
    // so the rest of the function only deals with the success case.
    let plan = plan_link(src, dst)?;

    match &plan {
        LinkPlan::Create { src, dst } => {
            if let Some(parent) = dst.parent() {
                fs::create_dir_all(parent).map_err(|e| LinkError::from_io(parent, &e))?;
            }

            create_symlink(src, dst).map_err(|e| {
                LinkError::from_io(format!("{} -> {}", src.display(), dst.display()), &e)
            })?;
        }
        LinkPlan::Conflict { .. } | LinkPlan::Noop => {}
    }

    Ok(plan)
}
