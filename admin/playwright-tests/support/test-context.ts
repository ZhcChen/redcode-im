export const adminE2EEnabled = process.env.ADMIN_E2E_ENABLED === 'true';

export const adminUsername = process.env.ADMIN_USERNAME || 'admin';
export const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';

export type AdminRouteProfile = 'default' | 'data-cleanup';

export function getAdminRouteProfile(): AdminRouteProfile {
  return process.env.ADMIN_ROUTE_PROFILE === 'default'
    ? 'default'
    : 'data-cleanup';
}
