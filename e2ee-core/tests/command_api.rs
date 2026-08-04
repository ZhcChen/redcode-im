use redcode_e2ee_core::execute_command;

const VERSION: [u8; 2] = 1_u16.to_be_bytes();

#[test]
fn command_api_runs_direct_message_flow_and_rejects_duplicate() {
    let alice = command(1, &[b"alice-device-1"]);
    let bob = command(1, &[b"bob-device-1"]);
    let alice_state = alice[0].clone();
    let bob_state = bob[0].clone();
    let bob_key_package = bob[1].clone();

    let created = command(3, &[&alice_state, b"room-direct-1"]);
    let added = command(4, &[&created[0], b"room-direct-1", &bob_key_package]);
    let joined = command(5, &[&bob_state, &added[2]]);
    let encrypted = command(6, &[&added[0], b"room-direct-1", b"hello"]);
    let decrypted = command(7, &[&joined[0], b"room-direct-1", &encrypted[1]]);

    assert_eq!(decrypted[1], b"hello");
    assert_eq!(
        u64::from_be_bytes(decrypted[2].clone().try_into().unwrap()),
        1
    );
    assert!(response_fields(&request(
        7,
        &[&decrypted[0], b"room-direct-1", &encrypted[1]],
    ))
    .is_err());
}

#[test]
fn command_api_fails_closed_for_malformed_input() {
    let response = execute_command(b"invalid");
    assert_eq!(&response[..4], b"RCCR");
    assert_eq!(response[6], 1);
    assert!(
        String::from_utf8(response_fields_raw(&response).unwrap()[0].clone())
            .unwrap()
            .contains("header")
    );
}

#[test]
fn initialization_returns_stable_registration_material() {
    let first = command(1, &[b"alice-device-1"]);
    assert_eq!(first.len(), 7);
    assert_eq!(first[2].len(), 32);
    assert_eq!(first[3].len(), 32);
    assert_eq!(first[5].len(), 32);
    assert_eq!(first[6].len(), 32);

    let second = command(1, &[b"alice-device-2", &first[2]]);
    assert_eq!(second[2], first[2]);
    assert_eq!(second[3], first[3]);
    assert_ne!(second[5], first[5]);
    assert_ne!(second[6], first[6]);
}

#[test]
fn generated_key_package_remains_joinable_after_state_restore() {
    let alice = command(1, &[b"alice-device-1"]);
    let bob = command(1, &[b"bob-device-1"]);
    let generated = command(2, &[&bob[0]]);
    let created = command(3, &[&alice[0], b"room-restored-key-package"]);
    let added = command(
        4,
        &[&created[0], b"room-restored-key-package", &generated[1]],
    );

    let joined = command(5, &[&generated[0], &added[2]]);
    assert_eq!(u64::from_be_bytes(joined[1].clone().try_into().unwrap()), 1);
}

fn command(operation: u8, fields: &[&[u8]]) -> Vec<Vec<u8>> {
    response_fields(&request(operation, fields)).expect("command succeeds")
}

fn request(operation: u8, fields: &[&[u8]]) -> Vec<u8> {
    let mut request = Vec::from(&b"RCCQ"[..]);
    request.extend_from_slice(&VERSION);
    request.push(operation);
    request.push(fields.len() as u8);
    for field in fields {
        request.extend_from_slice(&(field.len() as u32).to_be_bytes());
        request.extend_from_slice(field);
    }
    request
}

fn response_fields(request: &[u8]) -> Result<Vec<Vec<u8>>, String> {
    let response = execute_command(request);
    let fields = response_fields_raw(&response)?;
    if response[6] == 0 {
        Ok(fields)
    } else {
        Err(String::from_utf8_lossy(&fields[0]).into_owned())
    }
}

fn response_fields_raw(response: &[u8]) -> Result<Vec<Vec<u8>>, String> {
    if response.len() < 8 || &response[..4] != b"RCCR" {
        return Err("invalid response".to_string());
    }
    let mut offset = 8;
    let mut fields = Vec::new();
    for _ in 0..response[7] {
        let length = u32::from_be_bytes(response[offset..offset + 4].try_into().unwrap()) as usize;
        offset += 4;
        fields.push(response[offset..offset + length].to_vec());
        offset += length;
    }
    Ok(fields)
}
