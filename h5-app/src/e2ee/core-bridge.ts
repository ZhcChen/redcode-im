import initCore, {
  execute_command,
  new_protocol_state,
  protocol_version,
  validate_protocol_state,
} from '@/e2ee/core-wasm/redcode_e2ee_core.js';

const EXPECTED_PROTOCOL_VERSION = 1;

export class E2eeCoreUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'E2eeCoreUnavailableError';
  }
}

export interface E2eeCoreModule {
  initialize(): Promise<void>;
  protocolVersion(): number;
  newProtocolState(): Uint8Array;
  validateProtocolState(state: Uint8Array): boolean;
  executeCommand(command: Uint8Array): Uint8Array;
}

const wasmCore: E2eeCoreModule = {
  async initialize() {
    await initCore();
  },
  protocolVersion: protocol_version,
  newProtocolState: new_protocol_state,
  validateProtocolState: validate_protocol_state,
  executeCommand: execute_command,
};

export class E2eeCoreBridge {
  private initialization?: Promise<void>;

  constructor(private readonly core: E2eeCoreModule = wasmCore) {}

  async initialize(): Promise<void> {
    this.initialization ??= this.initializeOnce();
    return this.initialization;
  }

  async newProtocolState(): Promise<Uint8Array> {
    await this.initialize();
    const state = this.core.newProtocolState();
    if (!this.core.validateProtocolState(state)) {
      throw new E2eeCoreUnavailableError('共享 E2EE 核心生成了无效协议状态');
    }
    return state;
  }

  async validateProtocolState(state: Uint8Array): Promise<boolean> {
    await this.initialize();
    return this.core.validateProtocolState(state);
  }

  async executeCommand(command: Uint8Array): Promise<Uint8Array> {
    if (command.length === 0) {
      throw new E2eeCoreUnavailableError('E2EE 核心命令不能为空');
    }
    await this.initialize();
    return this.core.executeCommand(command);
  }

  private async initializeOnce(): Promise<void> {
    try {
      await this.core.initialize();
      const version = this.core.protocolVersion();
      if (version !== EXPECTED_PROTOCOL_VERSION) {
        throw new E2eeCoreUnavailableError(
          `不支持的 E2EE 核心协议版本: ${version}`,
        );
      }
    } catch (error) {
      if (error instanceof E2eeCoreUnavailableError) throw error;
      throw new E2eeCoreUnavailableError('共享 E2EE WASM 核心加载失败');
    }
  }
}

export const e2eeCoreBridge = new E2eeCoreBridge();

export const createNewE2eeProtocolState = () => e2eeCoreBridge.newProtocolState();
export const validateE2eeProtocolState = (state: Uint8Array) =>
  e2eeCoreBridge.validateProtocolState(state);
