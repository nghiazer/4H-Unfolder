import { Line } from 'react-konva';
import type { GlueTab } from '@/types/unfold';

interface Props {
  tab:   GlueTab;
  scale: number;
}

export function GlueTabShape({ tab, scale }: Props) {
  const s = scale;
  // Quad: p0(cut edge) → p1(cut edge) → p2(inset) → p3(inset)
  const points = [
    tab.p0.x * s, tab.p0.y * s,
    tab.p1.x * s, tab.p1.y * s,
    tab.p2.x * s, tab.p2.y * s,
    tab.p3.x * s, tab.p3.y * s,
  ];

  return (
    <Line
      points={points}
      closed
      fill="#d4edda"
      stroke="#5a9e6f"
      strokeWidth={0.5}
      opacity={0.8}
      listening={false}
    />
  );
}
