import protobuf from 'protobufjs';
import wsProto from './ws.proto?raw';

const root = protobuf.parse(wsProto, { keepCase: true }).root;

export const ClientEvent = root.lookupType('ws.ClientEvent');
export const ClientAuth = root.lookupType('ws.ClientAuth');
export const ClientJoin = root.lookupType('ws.ClientJoin');
export const ClientLeave = root.lookupType('ws.ClientLeave');
export const ClientPing = root.lookupType('ws.ClientPing');

export const ServerEvent = root.lookupType('ws.ServerEvent');
export const ServerAuthed = root.lookupType('ws.ServerAuthed');
export const ServerJoined = root.lookupType('ws.ServerJoined');
export const ServerLeft = root.lookupType('ws.ServerLeft');
export const ServerMessage = root.lookupType('ws.ServerMessage');
export const ServerMessageRead = root.lookupType('ws.ServerMessageRead');
export const ServerMessageUpdate = root.lookupType('ws.ServerMessageUpdate');
export const ServerPinUpdate = root.lookupType('ws.ServerPinUpdate');
export const ServerError = root.lookupType('ws.ServerError');
export const ServerPong = root.lookupType('ws.ServerPong');
export const ServerFriendRequestUpdate = root.lookupType('ws.ServerFriendRequestUpdate');
export const ServerRoomCreated = root.lookupType('ws.ServerRoomCreated');

export type WsMessagePayload = {
  [key: string]: unknown;
};

export const encodeClientAuth = (token: string): Uint8Array => {
  const message = ClientEvent.create({
    auth: ClientAuth.create({ token }),
  });
  return ClientEvent.encode(message).finish();
};

export const encodeClientPing = (): Uint8Array => {
  const message = ClientEvent.create({
    ping: ClientPing.create({}),
  });
  return ClientEvent.encode(message).finish();
};

export const encodeClientJoin = (roomId: string): Uint8Array => {
  const message = ClientEvent.create({
    join: ClientJoin.create({ room_id: roomId }),
  });
  return ClientEvent.encode(message).finish();
};

export const encodeClientLeave = (roomId: string): Uint8Array => {
  const message = ClientEvent.create({
    leave: ClientLeave.create({ room_id: roomId }),
  });
  return ClientEvent.encode(message).finish();
};

export const decodeServerEvent = (buffer: Uint8Array) => {
  return ServerEvent.decode(buffer);
};

export type ServerEventMessage = ReturnType<typeof decodeServerEvent>;
