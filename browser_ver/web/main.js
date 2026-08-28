// Smoke-test harness only -- proves the WASM core loads and ticks in an
// actual browser. The real render loop / UI replaces this file later.
const statusEl = document.getElementById("status");

const Module = {
  onSfx(id) {
    console.log("[sfx]", id);
  },
};

createTPCore(Module).then((mod) => {
  const seed = mod.cwrap("tp_seed_random", null, ["number"]);
  const tick = mod.cwrap("tp_tick", null, ["number"]);
  const status = mod.cwrap("tp_debug_status", "string", []);

  seed(Date.now() & 0xffffffff);

  let frames = 0;
  function loop(now) {
    tick(now | 0);
    frames++;
    if (frames % 30 === 0) {
      statusEl.textContent = `core status: ${status()}  (tick #${frames}, t=${now | 0}ms)`;
    }
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);
}).catch((err) => {
  statusEl.textContent = "WASM load failed: " + err;
  console.error(err);
});
