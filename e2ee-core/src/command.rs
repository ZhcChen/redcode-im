use crate::{MlsSession, MAX_STATE_BYTES, PROTOCOL_VERSION};

const REQUEST_MAGIC: &[u8; 4] = b"RCCQ";
const RESPONSE_MAGIC: &[u8; 4] = b"RCCR";
const HEADER_BYTES: usize = 8;
const MAX_FIELDS: usize = 8;
const MAX_COMMAND_BYTES: usize = MAX_STATE_BYTES + crate::MAX_PAYLOAD_BYTES + 1024 * 1024;

const INITIALIZE: u8 = 1;
const GENERATE_KEY_PACKAGE: u8 = 2;
const CREATE_GROUP: u8 = 3;
const ADD_MEMBER: u8 = 4;
const JOIN_GROUP: u8 = 5;
const ENCRYPT: u8 = 6;
const DECRYPT: u8 = 7;
const PUBLIC_MATERIAL: u8 = 8;
const PROCESS_COMMIT: u8 = 9;
const REMOVE_MEMBER: u8 = 10;
const SIGN_DEVICE_APPROVAL: u8 = 11;

#[cfg_attr(target_arch = "wasm32", wasm_bindgen::prelude::wasm_bindgen)]
pub fn execute_command(request: &[u8]) -> Vec<u8> {
    match execute(request) {
        Ok(fields) => encode_response(0, fields),
        Err(error) => encode_response(1, vec![error.into_bytes()]),
    }
}

fn execute(request: &[u8]) -> Result<Vec<Vec<u8>>, String> {
    let (operation, fields) = decode_request(request)?;
    match operation {
        INITIALIZE => {
            if !(1..=2).contains(&fields.len()) {
                return Err("invalid E2EE command field count".to_string());
            }
            let bootstrap =
                MlsSession::initialize_with_root(&fields[0], fields.get(1).map(Vec::as_slice))
                    .map_err(display)?;
            Ok(vec![
                bootstrap.state,
                bootstrap.key_package,
                bootstrap.public_material.root_public_key,
                bootstrap.public_material.root_fingerprint,
                bootstrap.public_material.credential,
                bootstrap.public_material.credential_fingerprint,
                bootstrap.public_material.approval_public_key,
            ])
        }
        GENERATE_KEY_PACKAGE => {
            require_fields(&fields, 1)?;
            let session = MlsSession::import(&fields[0]).map_err(display)?;
            let key_package = session.generate_key_package().map_err(display)?;
            Ok(vec![session.export_state().map_err(display)?, key_package])
        }
        CREATE_GROUP => {
            require_fields(&fields, 2)?;
            let mut session = MlsSession::import(&fields[0]).map_err(display)?;
            Ok(vec![session.create_group(&fields[1]).map_err(display)?])
        }
        ADD_MEMBER => {
            require_fields(&fields, 3)?;
            let mut session = MlsSession::import(&fields[0]).map_err(display)?;
            let added = session
                .add_member(&fields[1], &fields[2])
                .map_err(display)?;
            Ok(vec![
                added.state,
                added.commit,
                added.welcome,
                added.epoch.to_be_bytes().to_vec(),
            ])
        }
        JOIN_GROUP => {
            require_fields(&fields, 2)?;
            let mut session = MlsSession::import(&fields[0]).map_err(display)?;
            let (state, epoch) = session.join_group(&fields[1]).map_err(display)?;
            Ok(vec![state, epoch.to_be_bytes().to_vec()])
        }
        ENCRYPT => {
            require_fields(&fields, 3)?;
            let mut session = MlsSession::import(&fields[0]).map_err(display)?;
            let (ciphertext, epoch, state) =
                session.encrypt(&fields[1], &fields[2]).map_err(display)?;
            Ok(vec![state, ciphertext, epoch.to_be_bytes().to_vec()])
        }
        DECRYPT => {
            require_fields(&fields, 3)?;
            let mut session = MlsSession::import(&fields[0]).map_err(display)?;
            let application = session.decrypt(&fields[1], &fields[2]).map_err(display)?;
            Ok(vec![
                application.state,
                application.plaintext,
                application.epoch.to_be_bytes().to_vec(),
            ])
        }
        PUBLIC_MATERIAL => {
            require_fields(&fields, 1)?;
            let session = MlsSession::import(&fields[0]).map_err(display)?;
            let material = session.public_material().map_err(display)?;
            Ok(vec![
                session.export_state().map_err(display)?,
                material.root_public_key,
                material.root_fingerprint,
                material.credential,
                material.credential_fingerprint,
                material.approval_public_key,
            ])
        }
        PROCESS_COMMIT => {
            require_fields(&fields, 3)?;
            let mut session = MlsSession::import(&fields[0]).map_err(display)?;
            let (state, epoch) = session
                .process_commit(&fields[1], &fields[2])
                .map_err(display)?;
            Ok(vec![state, epoch.to_be_bytes().to_vec()])
        }
        REMOVE_MEMBER => {
            require_fields(&fields, 3)?;
            let mut session = MlsSession::import(&fields[0]).map_err(display)?;
            let removed = session
                .remove_member(&fields[1], &fields[2])
                .map_err(display)?;
            Ok(vec![
                removed.state,
                removed.commit,
                removed.epoch.to_be_bytes().to_vec(),
            ])
        }
        SIGN_DEVICE_APPROVAL => {
            require_fields(&fields, 2)?;
            let session = MlsSession::import(&fields[0]).map_err(display)?;
            let signature = session.sign_device_approval(&fields[1]).map_err(display)?;
            Ok(vec![signature])
        }
        _ => Err("unsupported E2EE command".to_string()),
    }
}

fn decode_request(request: &[u8]) -> Result<(u8, Vec<Vec<u8>>), String> {
    if request.len() > MAX_COMMAND_BYTES {
        return Err("E2EE command is too large".to_string());
    }
    if request.len() < HEADER_BYTES || &request[..4] != REQUEST_MAGIC {
        return Err("invalid E2EE command header".to_string());
    }
    let version = u16::from_be_bytes([request[4], request[5]]);
    if version != PROTOCOL_VERSION {
        return Err("unsupported E2EE command version".to_string());
    }
    let operation = request[6];
    let field_count = request[7] as usize;
    if field_count > MAX_FIELDS {
        return Err("too many E2EE command fields".to_string());
    }
    let mut offset = HEADER_BYTES;
    let mut fields = Vec::with_capacity(field_count);
    for _ in 0..field_count {
        let length_end = offset.checked_add(4).ok_or("E2EE command is too large")?;
        let length_bytes = request
            .get(offset..length_end)
            .ok_or("truncated E2EE command field")?;
        offset = length_end;
        let length = u32::from_be_bytes(length_bytes.try_into().expect("fixed length")) as usize;
        if length > MAX_STATE_BYTES {
            return Err("E2EE command field is too large".to_string());
        }
        let end = offset
            .checked_add(length)
            .ok_or("E2EE command is too large")?;
        fields.push(
            request
                .get(offset..end)
                .ok_or("truncated E2EE command field")?
                .to_vec(),
        );
        offset = end;
    }
    if offset != request.len() {
        return Err("E2EE command contains trailing bytes".to_string());
    }
    Ok((operation, fields))
}

fn encode_response(status: u8, fields: Vec<Vec<u8>>) -> Vec<u8> {
    let mut response = Vec::with_capacity(
        HEADER_BYTES + fields.iter().map(|field| 4 + field.len()).sum::<usize>(),
    );
    response.extend_from_slice(RESPONSE_MAGIC);
    response.extend_from_slice(&PROTOCOL_VERSION.to_be_bytes());
    response.push(status);
    response.push(fields.len() as u8);
    for field in fields {
        response.extend_from_slice(&(field.len() as u32).to_be_bytes());
        response.extend_from_slice(&field);
    }
    response
}

fn require_fields(fields: &[Vec<u8>], count: usize) -> Result<(), String> {
    if fields.len() != count {
        return Err("invalid E2EE command field count".to_string());
    }
    Ok(())
}

fn display(error: impl std::fmt::Display) -> String {
    error.to_string()
}

#[no_mangle]
pub unsafe extern "C" fn rc_e2ee_command_execute(
    input: *const u8,
    input_length: usize,
    output: *mut *mut u8,
    output_length: *mut usize,
) -> i32 {
    if input.is_null() || output.is_null() || output_length.is_null() {
        return -1;
    }
    let request = unsafe { std::slice::from_raw_parts(input, input_length) };
    let mut response = execute_command(request).into_boxed_slice();
    let length = response.len();
    let pointer = response.as_mut_ptr();
    std::mem::forget(response);
    unsafe {
        *output = pointer;
        *output_length = length;
    }
    0
}

#[no_mangle]
pub unsafe extern "C" fn rc_e2ee_command_free(output: *mut u8, length: usize) {
    if output.is_null() || length == 0 {
        return;
    }
    let mut response = unsafe { Box::from_raw(std::ptr::slice_from_raw_parts_mut(output, length)) };
    response.fill(0);
}
