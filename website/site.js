(() => {
  const header = document.querySelector(".site-header");
  const onScroll = () => {
    if (!header) return;
    header.classList.toggle("is-scrolled", window.scrollY > 12);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
          io.unobserve(entry.target);
        }
      }
    },
    { threshold: 0.18, rootMargin: "0px 0px -8% 0px" }
  );
  document.querySelectorAll(".reveal, .flow-step").forEach((el) => io.observe(el));

  // Prefer native video when the MP4 exists; otherwise keep poster CTA.
  const video = document.querySelector("#overview-video");
  const placeholder = document.querySelector("#overview-placeholder");
  if (video && placeholder) {
    const source = video.querySelector("source");
    const probe = new Image(); // reuse network path check via fetch HEAD
    const url = source ? source.getAttribute("src") : "";
    if (url) {
      fetch(url, { method: "HEAD" })
        .then((res) => {
          if (!res.ok) throw new Error("missing");
          placeholder.hidden = true;
          video.hidden = false;
        })
        .catch(() => {
          video.hidden = true;
          placeholder.hidden = false;
        });
    }
  }
})();
