import http from '@/services/http';

export interface PermissionInfo {
  id: string;
  name: string;
  code: string;
  description?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface RoleInfo {
  id: string;
  name: string;
  code: string;
  description?: string | null;
  isSystem: boolean;
  createdAt: string;
  updatedAt: string;
  permissions: PermissionInfo[];
}

export interface RolePermissionAssignment {
  roleId: string;
  permissionIds: string[];
  permissionCodes: string[];
}

export interface AdminUserRoleAssignment {
  adminUserId: string;
  roleIds: string[];
  roleCodes: string[];
}

export interface CreateRolePayload {
  name: string;
  code: string;
  description?: string | null;
  permissionIds: string[];
}

export interface UpdateRolePayload {
  name?: string;
  description?: string | null;
  permissionIds?: string[];
}

interface BackendPermissionInfo {
  id: string;
  name: string;
  code: string;
  description?: string | null;
  created_at?: string;
  createdAt?: string;
  updated_at?: string;
  updatedAt?: string;
}

interface BackendRoleInfo {
  id: string;
  name: string;
  code: string;
  description?: string | null;
  is_system?: boolean;
  isSystem?: boolean;
  created_at?: string;
  createdAt?: string;
  updated_at?: string;
  updatedAt?: string;
  permissions?: BackendPermissionInfo[];
}

interface BackendRolePermissionAssignment {
  role_id?: string;
  roleId?: string;
  permission_ids?: string[];
  permissionIds?: string[];
  permission_codes?: string[];
  permissionCodes?: string[];
}

interface BackendAdminUserRoleAssignment {
  admin_user_id?: string;
  adminUserId?: string;
  role_ids?: string[];
  roleIds?: string[];
  role_codes?: string[];
  roleCodes?: string[];
}

function normalizePermission(
  permission: BackendPermissionInfo
): PermissionInfo {
  return {
    id: permission.id,
    name: permission.name,
    code: permission.code,
    description: permission.description ?? null,
    createdAt: permission.createdAt ?? permission.created_at ?? '',
    updatedAt: permission.updatedAt ?? permission.updated_at ?? '',
  };
}

function normalizeRole(role: BackendRoleInfo): RoleInfo {
  return {
    id: role.id,
    name: role.name,
    code: role.code,
    description: role.description ?? null,
    isSystem: role.isSystem ?? role.is_system ?? false,
    createdAt: role.createdAt ?? role.created_at ?? '',
    updatedAt: role.updatedAt ?? role.updated_at ?? '',
    permissions: (role.permissions || []).map(normalizePermission),
  };
}

function normalizeRolePermissionAssignment(
  assignment: BackendRolePermissionAssignment
): RolePermissionAssignment {
  return {
    roleId: assignment.roleId ?? assignment.role_id ?? '',
    permissionIds: assignment.permissionIds ?? assignment.permission_ids ?? [],
    permissionCodes:
      assignment.permissionCodes ?? assignment.permission_codes ?? [],
  };
}

function normalizeAdminUserRoleAssignment(
  assignment: BackendAdminUserRoleAssignment
): AdminUserRoleAssignment {
  return {
    adminUserId: assignment.adminUserId ?? assignment.admin_user_id ?? '',
    roleIds: assignment.roleIds ?? assignment.role_ids ?? [],
    roleCodes: assignment.roleCodes ?? assignment.role_codes ?? [],
  };
}

export function getPermissionList() {
  return http
    .get<{ permissions: BackendPermissionInfo[] }>('/api/admin/permissions')
    .then((res) => ({
      ...res,
      data: {
        permissions: (res.data.permissions || []).map(normalizePermission),
      },
    }));
}

export function getRoleList() {
  return http
    .get<{ roles: BackendRoleInfo[] }>('/api/admin/roles')
    .then((res) => ({
      ...res,
      data: {
        roles: (res.data.roles || []).map(normalizeRole),
      },
    }));
}

export function createRole(payload: CreateRolePayload) {
  return http.post<BackendRoleInfo>('/api/admin/roles', {
    name: payload.name,
    code: payload.code,
    description: payload.description ?? null,
    permission_ids: payload.permissionIds,
  });
}

export function updateRole(roleId: string, payload: UpdateRolePayload) {
  return http.patch<BackendRoleInfo>(`/api/admin/roles/${roleId}`, {
    name: payload.name,
    description: payload.description ?? null,
    permission_ids: payload.permissionIds,
  });
}

export function deleteRole(roleId: string) {
  return http.delete<{ success: boolean; message: string }>(
    `/api/admin/roles/${roleId}`
  );
}

export function getRolePermissionAssignment(roleId: string) {
  return http
    .get<BackendRolePermissionAssignment>(
      `/api/admin/roles/${roleId}/permissions`
    )
    .then((res) => ({
      ...res,
      data: normalizeRolePermissionAssignment(res.data),
    }));
}

export function updateRolePermissionAssignment(
  roleId: string,
  permissionIds: string[]
) {
  return http.put<BackendRolePermissionAssignment>(
    `/api/admin/roles/${roleId}/permissions`,
    {
      permission_ids: permissionIds,
    }
  );
}

export function getAdminUserRoleAssignment(adminUserId: string) {
  return http
    .get<BackendAdminUserRoleAssignment>(
      `/api/admin/admin-users/${adminUserId}/roles`
    )
    .then((res) => ({
      ...res,
      data: normalizeAdminUserRoleAssignment(res.data),
    }));
}

export function updateAdminUserRoleAssignment(
  adminUserId: string,
  roleIds: string[]
) {
  return http.put<BackendAdminUserRoleAssignment>(
    `/api/admin/admin-users/${adminUserId}/roles`,
    {
      role_ids: roleIds,
    }
  );
}
