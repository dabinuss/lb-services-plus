import type { Category, Company } from "../types";

function normalize(value: string) {
  return value.trim().toLocaleLowerCase();
}

export function filterCompanies(companies: Company[], categories: Category[], query: string, categoryId: string) {
  const term = normalize(query);
  const categoryById = new Map(categories.map((category) => [category.id, category]));
  return companies.filter((company) => {
    if (categoryId !== "all" && company.categoryId !== categoryId) return false;
    if (!term) return true;
    const category = categoryById.get(company.categoryId);
    const values = [
      company.displayName,
      company.categoryName,
      company.description,
      company.location,
      ...company.keywords,
      ...(category?.keywords ?? [])
    ];
    return values.some((value) => normalize(value).includes(term));
  });
}
