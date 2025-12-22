// utils/csrf.ts
export const getCSRFToken = (): string | null => {
    const csrfToken = document.cookie
      .split(';')
      .find((cookie) => cookie.trim().startsWith('csrftoken='));
  
    return csrfToken ? csrfToken.split('=')[1] : null;
  };
  