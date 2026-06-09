fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 默认启用 SQLx 离线模式，避免“刚删库/空库导致编译期 query! 校验失败”的开发痛点。
    //
    // 说明：
    // - `cargo sqlx prepare` 会生成 `api/.sqlx/` 查询元数据，供离线编译使用；
    // - 如需强制在线校验，可在构建时设置 `SQLX_OFFLINE=0` 并确保 `DATABASE_URL` 指向已迁移的数据库。
    println!("cargo:rerun-if-env-changed=SQLX_OFFLINE");
    if std::env::var("SQLX_OFFLINE").is_err() {
        println!("cargo:rustc-env=SQLX_OFFLINE=true");
    }

    let protoc_path = protoc_bin_vendored::protoc_bin_path()?;
    std::env::set_var("PROTOC", protoc_path);

    let proto_files = ["proto/ws.proto"];
    for file in &proto_files {
        println!("cargo:rerun-if-changed={}", file);
    }

    prost_build::Config::new().compile_protos(&proto_files, &["proto"])?;

    Ok(())
}
