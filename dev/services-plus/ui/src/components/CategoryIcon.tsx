import { BriefcaseBusiness, Building2, CarTaxiFront, HeartPulse, Landmark, LayoutGrid, Music, Radio, Shield, ShoppingBag, Utensils, Wrench } from "lucide-react";

const icons = {
  shield: Shield, "heart-pulse": HeartPulse, "car-taxi-front": CarTaxiFront, wrench: Wrench,
  utensils: Utensils, "shopping-bag": ShoppingBag, landmark: Landmark, "building-2": Building2,
  radio: Radio, music: Music, "briefcase-business": BriefcaseBusiness
};

export function CategoryIcon({ name, size = 18 }: { name?: string; size?: number }) {
  const Icon = icons[name as keyof typeof icons] ?? LayoutGrid;
  return <Icon size={size} aria-hidden="true" />;
}
