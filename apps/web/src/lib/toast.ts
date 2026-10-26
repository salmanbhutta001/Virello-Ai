// Global toast — port of legacy showToast (index.html:2630).
// Single toast, visible ~4,200 ms. The element lives in <ToastRoot />
// (mounted once in layout.tsx); showToast is callable from anywhere,
// including non-React code (auth.ts logout, pricing modals).

let toastTimer: ReturnType<typeof setTimeout> | null = null;

export function showToast(msg: string): void {
  if (typeof document === 'undefined') return;
  const t = document.getElementById('toast');
  if (!t) return;
  t.textContent = msg;
  t.classList.add('show');
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    t.classList.remove('show');
  }, 4200);
}
