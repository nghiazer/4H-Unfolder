import { Rect } from 'react-konva';

interface Props {
  widthMm:  number;
  heightMm: number;
  scale:    number;
}

export function SheetBackground({ widthMm, heightMm, scale }: Props) {
  return (
    <Rect
      x={0}
      y={0}
      width={widthMm * scale}
      height={heightMm * scale}
      fill="#ffffff"
      stroke="#cccccc"
      strokeWidth={1}
      shadowColor="rgba(0,0,0,0.15)"
      shadowBlur={8}
      shadowOffset={{ x: 2, y: 2 }}
      listening={false}
    />
  );
}
