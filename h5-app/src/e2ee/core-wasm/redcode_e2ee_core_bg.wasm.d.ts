/* tslint:disable */
/* eslint-disable */
export const memory: WebAssembly.Memory;
export const new_protocol_state: () => [number, number];
export const protocol_version: () => number;
export const rc_e2ee_protocol_version: () => number;
export const rc_e2ee_state_new: (a: number, b: number) => number;
export const rc_e2ee_state_validate: (a: number, b: number) => number;
export const validate_protocol_state: (a: number, b: number) => number;
export const execute_command: (a: number, b: number) => [number, number];
export const rc_e2ee_command_execute: (a: number, b: number, c: number, d: number) => number;
export const rc_e2ee_command_free: (a: number, b: number) => void;
export const __wbindgen_exn_store: (a: number) => void;
export const __externref_table_alloc: () => number;
export const __wbindgen_externrefs: WebAssembly.Table;
export const __wbindgen_malloc: (a: number, b: number) => number;
export const __wbindgen_free: (a: number, b: number, c: number) => void;
export const __wbindgen_start: () => void;
