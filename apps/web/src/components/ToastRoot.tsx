// The single global toast element (legacy #toast, index.html:2131).
// Mounted once in the root layout; showToast() in src/lib/toast.ts
// drives it. No props, no state — the DOM node is the toast.
export default function ToastRoot() {
  return <div className="toast" id="toast" role="status" />;
}
