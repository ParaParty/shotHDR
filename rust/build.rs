fn main() {
    // Force linking of C++ standard library
    if std::env::var("CARGO_CFG_TARGET_OS").unwrap() == "macos" {
        println!("cargo:rustc-link-lib=c++");
    }
}
