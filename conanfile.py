from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout, CMakeDeps


class mdotRecipe(ConanFile):
    name = "mdot"
    version = "1.0"
    package_type = "application"

    # Optional metadata
    # license = "<Put the package license here>"
    author = "NexushasTaken nexushastaken@gmail.com"
    # url = "<Package recipe repository url here, for issues about the package>"
    description = "mdot dotfile manager"
    # topics = ("<Put some tag here>", "<here>", "<and here>")

    # Binary configuration
    settings = "os", "compiler", "build_type", "arch"

    # Sources are located in the same place as this recipe, copy them to the recipe
    exports_sources = "CMakeLists.txt", "src/*"

    default_options = {"cli11/*:header_only": False}

    def layout(self):
        cmake_layout(self)

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()
        tc = CMakeToolchain(self)
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def requirements(self):
        self.requires("spdlog/1.17.0")
        self.requires("tl-expected/20190710")
        self.requires("cli11/2.7.2")
        self.test_requires("catch2/3.16.0")
