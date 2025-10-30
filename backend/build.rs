fn main() -> Result<(), Box<dyn std::error::Error>> {
    let protoc_path = protoc_bin_vendored::protoc_bin_path()?;
    std::env::set_var("PROTOC", protoc_path);

    let proto_files = ["proto/ws.proto"];
    for file in &proto_files {
        println!("cargo:rerun-if-changed={}", file);
    }

    prost_build::Config::new().compile_protos(&proto_files, &["proto"])?;

    Ok(())
}
