import { Building2, CarTaxiFront, Gavel, HeartPulse, LayoutGrid, Newspaper, Package, Shield, Users, Utensils, Wrench } from "lucide-react";

const icons = {
  shield: Shield, gavel: Gavel, "heart-pulse": HeartPulse, "car-taxi-front": CarTaxiFront, wrench: Wrench,
  utensils: Utensils, package: Package, newspaper: Newspaper, users: Users, "building-2": Building2
};

export function CategoryIcon({ name, size = 18 }: { name?: string; size?: number }) {
  const Icon = icons[name as keyof typeof icons] ?? LayoutGrid;
  return <Icon size={size} aria-hidden="true" />;
}
