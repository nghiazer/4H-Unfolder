import { Line } from 'react-konva';
import type { GlueTab } from '@/types/unfold';

interface Props {
  tab:   GlueTab;
  scale: number;
}

export function GlueTabShape({ tab, scale }: Props) {
  const points = tab.polygon.flatMap((v) => [v.x * scale, v.y * scale]);

  return (
    <Line
      points={points}
      closed
      fill="#d4edda"
      stroke="#5a9e6f"
      strokeWidth={0.5}
      dash={[3, 2]}
      opacity={0.8}
      listening={false}
    />
  );
}
