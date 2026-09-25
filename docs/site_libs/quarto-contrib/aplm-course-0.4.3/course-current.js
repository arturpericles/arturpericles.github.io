/* Civil dates are compared in the course timezone, without parsing them as UTC. */
const courseCurrentClass = (() => {
  function dateKey(now, timeZone) {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone, year: "numeric", month: "2-digit", day: "2-digit",
    }).formatToParts(now);
    const part = type => parts.find(value => value.type === type).value;
    return `${part("year")}-${part("month")}-${part("day")}`;
  }

  function classIndex(dates, today) {
    return dates.findIndex(date => date >= today);
  }

  function shouldAutoScroll(hash, navigationType) {
    return !hash && navigationType !== "back_forward" && navigationType !== "reload";
  }

  return { dateKey, classIndex, shouldAutoScroll };
})();

if (typeof module !== "undefined" && module.exports) {
  module.exports = courseCurrentClass;
}

if (typeof document !== "undefined") document.addEventListener("DOMContentLoaded", () => {
  const navigation = document.querySelector(".course-schedule-navigation");
  if (!navigation) return;
  const cards = [...document.querySelectorAll(".course-meeting[data-class-date]")];
  const today = courseCurrentClass.dateKey(new Date(), navigation.dataset.timeZone);
  const index = courseCurrentClass.classIndex(cards.map(card => card.dataset.classDate), today);
  if (index < 0) {
    if (cards.length) navigation.textContent = "All scheduled classes have concluded.";
    return;
  }

  const card = cards[index];
  const isToday = card.dataset.classDate === today;
  const label = isToday ? "Today’s class" : "Next class";
  card.classList.add("course-meeting-current");
  card.setAttribute("aria-current", isToday ? "date" : "true");
  card.setAttribute("tabindex", "-1");
  const marker = document.createElement("span");
  marker.className = "course-meeting-current-label";
  marker.textContent = label;
  card.querySelector(".course-meeting-kicker").prepend(marker);

  const jump = document.createElement("a");
  jump.href = `#${card.id}`;
  const dateLabel = new Intl.DateTimeFormat("en-US", {
    timeZone: "UTC", weekday: "short", month: "short", day: "numeric",
  }).format(new Date(`${card.dataset.classDate}T12:00:00Z`));
  jump.textContent = `${label} · ${dateLabel}`;
  navigation.append(jump);

  const returnLink = document.createElement("a");
  returnLink.className = "course-schedule-return";
  returnLink.href = "#quarto-document-content";
  returnLink.textContent = "Schedule overview and updates ↑";
  card.append(returnLink);

  // Keep direct links and restored reading positions; never take keyboard focus.
  const navigationType = performance.getEntriesByType("navigation")[0]?.type;
  if (!courseCurrentClass.shouldAutoScroll(location.hash, navigationType)) return;
  let interrupted = false;
  const cancel = () => { interrupted = true; };
  const events = ["wheel", "touchstart", "pointerdown", "keydown"];
  events.forEach(event => window.addEventListener(event, cancel, { passive: true, once: true }));
  const loaded = document.readyState === "complete" ? Promise.resolve()
    : new Promise(resolve => window.addEventListener("load", resolve, { once: true }));
  Promise.all([loaded, document.fonts.ready]).then(() => requestAnimationFrame(() => {
    events.forEach(event => window.removeEventListener(event, cancel));
    if (!interrupted && !location.hash) {
      card.scrollIntoView({ behavior: "instant", block: "start" });
    }
  }));
});
