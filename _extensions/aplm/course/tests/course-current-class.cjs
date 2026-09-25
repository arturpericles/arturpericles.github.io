const { test } = require("node:test");
const assert = require("node:assert/strict");
const { dateKey, classIndex, shouldAutoScroll } = require("../course-current.js");
const dates = ["2026-08-17", "2026-09-04", "2026-09-11", "2026-09-28", "2026-10-07", "2026-10-09", "2026-12-02"];

test("same-day class stays current for the whole course-local date", () => {
  assert.equal(classIndex(dates, "2026-10-07"), 4);
  assert.equal(dateKey(new Date("2026-10-08T04:59:59Z"), "America/Chicago"), "2026-10-07");
});
test("gaps, weekends, and cancelled dates advance to the next counted class", () => {
  assert.equal(classIndex(dates, "2026-09-09"), 2);
  assert.equal(classIndex(dates, "2026-09-27"), 3);
  assert.equal(classIndex(dates, "2026-10-08"), 5);
});
test("semester boundaries and an empty schedule", () => {
  assert.equal(classIndex(dates, "2026-08-01"), 0);
  assert.equal(classIndex(dates, "2026-12-02"), 6);
  assert.equal(classIndex(dates, "2026-12-03"), -1);
  assert.equal(classIndex([], "2026-09-24"), -1);
});
test("Mississippi midnight differs from UTC and respects daylight saving time", () => {
  assert.equal(dateKey(new Date("2026-09-25T02:00:00Z"), "America/Chicago"), "2026-09-24");
  assert.equal(dateKey(new Date("2026-09-25T05:00:00Z"), "America/Chicago"), "2026-09-25");
  assert.equal(dateKey(new Date("2026-12-03T05:59:59Z"), "America/Chicago"), "2026-12-02");
  assert.equal(dateKey(new Date("2026-12-03T06:00:00Z"), "America/Chicago"), "2026-12-03");
});
test("direct links, reloads, and history restoration keep their destination", () => {
  assert.equal(shouldAutoScroll("#comparative-negligence", "navigate"), false);
  assert.equal(shouldAutoScroll("", "back_forward"), false);
  assert.equal(shouldAutoScroll("", "reload"), false);
  assert.equal(shouldAutoScroll("", "navigate"), true);
});
