fn main() {
    // 编译 Protocol Buffers
    let proto_path = "../src/proto/ws.proto";
    prost_build::compile_protos(&[proto_path], &["../src/proto"])
        .expect("Failed to compile protobuf");

    tauri_build::build()
}
