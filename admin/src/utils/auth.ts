const TOKEN_KEY = 'token';
const REFRESH_TOKEN_KEY = 'refresh_token';

const isLogin = () => {
  return !!localStorage.getItem(TOKEN_KEY);
};

const getToken = () => {
  return localStorage.getItem(TOKEN_KEY);
};

const setToken = (token: string) => {
  localStorage.setItem(TOKEN_KEY, token);
};

const clearToken = () => {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
};

const getRefreshToken = () => {
  return localStorage.getItem(REFRESH_TOKEN_KEY);
};

const setRefreshToken = (refreshToken: string | null | undefined) => {
  if (refreshToken && refreshToken.length > 0) {
    localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
  } else {
    localStorage.removeItem(REFRESH_TOKEN_KEY);
  }
};

export {
  isLogin,
  getToken,
  setToken,
  clearToken,
  getRefreshToken,
  setRefreshToken,
};
