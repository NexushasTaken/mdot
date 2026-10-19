#include "error.hpp"

namespace fs = std::filesystem;

tl::unexpected<Error> make_error(const fs::path &path, std::error_code ec) {
  return tl::make_unexpected(Error{path, ec.message()});
}

tl::unexpected<Error> make_error(const fs::path &path, std::string message) {
  return tl::make_unexpected(Error{path, message});
}
