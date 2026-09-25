document.addEventListener("DOMContentLoaded", () => {
  const references = document.querySelectorAll(".course-material-abbr");
  if (!references.length || !window.tippy) return;
  const tooltips = window.tippy(references, {
    content: element => element.dataset.courseCitation,
    allowHTML: true,
    theme: "quarto course-citation",
    placement: "top-start",
    maxWidth: 360,
    arrow: false,
    interactive: true,
    appendTo: () => document.body,
    trigger: "mouseenter focus click",
    hideOnClick: true,
    aria: { content: "describedby", expanded: false },
  });
  document.addEventListener("keydown", event => {
    if (event.key === "Escape") tooltips.forEach(tooltip => tooltip.hide());
  });
});
