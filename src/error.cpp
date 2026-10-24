#include "error.hpp"
#include <format>

namespace mdot {

namespace fs = std::filesystem;

tl::unexpected<LinkError> LinkError::make_error(const fs::path &path,
                                                std::error_code ec) {
  return tl::make_unexpected(LinkError{path, ec.message()});
}

tl::unexpected<LinkError> LinkError::make_error(const fs::path &path,
                                                std::string message) {
  return tl::make_unexpected(LinkError{path, message});
}

tl::unexpected<ClauseError> ClauseError::make_error(std::size_t id,
                                                    std::string message) {
  return tl::make_unexpected(ClauseError{
      .m_id = id,
      .m_message = message,
  });
}

std::string ClauseError::string() const {
  return std::format("entry {}: {}", m_id, m_message);
}

} // namespace mdot
