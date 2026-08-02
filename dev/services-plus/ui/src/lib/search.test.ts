import { describe, expect, it } from "vitest";
import { browserFixture } from "../test/fixture";
import { filterCompanies } from "./search";

describe("filterCompanies", () => {
  it("matches company names and category keywords locally", () => {
    expect(filterCompanies(browserFixture.companies, browserFixture.categories, "Downtown", "all").map((item) => item.id)).toEqual(["downtown-cab"]);
    expect(filterCompanies(browserFixture.companies, browserFixture.categories, "cab", "all").map((item) => item.id)).toEqual(["downtown-cab", "yellow-jack"]);
    expect(filterCompanies(browserFixture.companies, browserFixture.categories, "hospital", "all").map((item) => item.id)).toEqual(["pillbox"]);
  });

  it("combines category and query filters", () => {
    expect(filterCompanies(browserFixture.companies, browserFixture.categories, "repair", "vehicle_services").map((item) => item.id)).toEqual(["bennys"]);
    expect(filterCompanies(browserFixture.companies, browserFixture.categories, "taxi", "vehicle_services")).toEqual([]);
  });

  it("filters one hundred loaded companies without a server request", () => {
    const companies = Array.from({ length: 100 }, (_, index) => ({
      ...browserFixture.companies[0],
      id: `company-${index}`,
      displayName: `Service ${index}`
    }));
    expect(filterCompanies(companies, browserFixture.categories, "Service 99", "all")).toHaveLength(1);
  });
});
