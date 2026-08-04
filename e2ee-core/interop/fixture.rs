const FIXTURE_MAGIC: &[u8; 4] = b"RCFX";
const FIXTURE_VERSION: u16 = 1;

pub struct CrossRuntimeFixture {
    pub group_id: Vec<u8>,
    pub provider_state: Vec<u8>,
    pub first_message: Vec<u8>,
    pub second_message: Vec<u8>,
}

impl CrossRuntimeFixture {
    pub fn encode(&self) -> Vec<u8> {
        let mut encoded = Vec::new();
        encoded.extend_from_slice(FIXTURE_MAGIC);
        encoded.extend_from_slice(&FIXTURE_VERSION.to_be_bytes());
        for field in [
            &self.group_id,
            &self.provider_state,
            &self.first_message,
            &self.second_message,
        ] {
            encoded.extend_from_slice(&(field.len() as u32).to_be_bytes());
            encoded.extend_from_slice(field);
        }
        encoded
    }

    pub fn decode(encoded: &[u8]) -> Result<Self, &'static str> {
        if encoded.len() < 6 || &encoded[..4] != FIXTURE_MAGIC {
            return Err("invalid fixture magic");
        }
        if u16::from_be_bytes([encoded[4], encoded[5]]) != FIXTURE_VERSION {
            return Err("unsupported fixture version");
        }

        let mut offset = 6;
        let group_id = read_field(encoded, &mut offset)?;
        let provider_state = read_field(encoded, &mut offset)?;
        let first_message = read_field(encoded, &mut offset)?;
        let second_message = read_field(encoded, &mut offset)?;
        if offset != encoded.len() {
            return Err("trailing fixture bytes");
        }
        Ok(Self {
            group_id,
            provider_state,
            first_message,
            second_message,
        })
    }
}

fn read_field(encoded: &[u8], offset: &mut usize) -> Result<Vec<u8>, &'static str> {
    let length_end = offset.checked_add(4).ok_or("fixture length overflow")?;
    let length_bytes = encoded
        .get(*offset..length_end)
        .ok_or("truncated fixture length")?;
    let length = u32::from_be_bytes(
        length_bytes
            .try_into()
            .map_err(|_| "invalid fixture length")?,
    ) as usize;
    let field_end = length_end
        .checked_add(length)
        .ok_or("fixture field overflow")?;
    let field = encoded
        .get(length_end..field_end)
        .ok_or("truncated fixture field")?
        .to_vec();
    *offset = field_end;
    Ok(field)
}
