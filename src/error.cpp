#include "error.hpp"

namespace fs = std::filesystem;

tl::unexpected<LinkError> LinkError::make_error(const fs::path &path, std::error_code ec) {
  return tl::make_unexpected(LinkError{path, ec.message()});
}

tl::unexpected<LinkError> LinkError::make_error(const fs::path &path, std::string message) {
  return tl::make_unexpected(LinkError{path, message});
}
