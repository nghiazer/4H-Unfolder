import { Rect, Line, Text, Group } from 'react-konva';
import { useSettingsStore } from '@/state/settingsStore';

interface Props {
  widthMm:  number;
  heightMm: number;
  scale:    number;
}

export function SheetBackground({ widthMm, heightMm, scale }: Props) {
  const settings = useSettingsStore((s) => s.settings);
  const { pagesWide, pagesTall, showPageNumbers } = settings;

  const totalW = widthMm * scale;
  const totalH = heightMm * scale;

  // Page size in pixels
  const pgW = totalW / pagesWide;
  const pgH = totalH / pagesTall;

  return (
    <Group>
      {/* Paper background */}
      <Rect
        x={0}
        y={0}
        width={totalW}
        height={totalH}
        fill="#ffffff"
        stroke="#cccccc"
        strokeWidth={1}
        shadowColor="rgba(0,0,0,0.15)"
        shadowBlur={8}
        shadowOffset={{ x: 2, y: 2 }}
        listening={false}
      />

      {/* Page grid lines (dashed) when multi-page */}
      {(pagesWide > 1 || pagesTall > 1) && (
        <>
          {/* Vertical page dividers */}
          {Array.from({ length: pagesWide - 1 }, (_, i) => (
            <Line
              key={`v${i}`}
              points={[(i + 1) * pgW, 0, (i + 1) * pgW, totalH]}
              stroke="#bbbbbb"
              strokeWidth={0.8}
              dash={[4, 4]}
              listening={false}
            />
          ))}

          {/* Horizontal page dividers */}
          {Array.from({ length: pagesTall - 1 }, (_, i) => (
            <Line
              key={`h${i}`}
              points={[0, (i + 1) * pgH, totalW, (i + 1) * pgH]}
              stroke="#bbbbbb"
              strokeWidth={0.8}
              dash={[4, 4]}
              listening={false}
            />
          ))}

          {/* Page number labels */}
          {showPageNumbers && Array.from({ length: pagesTall }, (_, pr) =>
            Array.from({ length: pagesWide }, (_, pc) => (
              <Text
                key={`lbl${pr}-${pc}`}
                x={pc * pgW + 6}
                y={pr * pgH + 6}
                text={`p${pr + 1},${pc + 1}`}
                fontSize={9}
                fill="#aaaaaa"
                listening={false}
              />
            ))
          )}
        </>
      )}
    </Group>
  );
}
