import { clsx } from 'clsx';
import { Loader2 } from 'lucide-react';

interface Props {
  icon:      React.ReactNode;
  label:     string;
  active?:   boolean;
  disabled?: boolean;
  loading?:  boolean;
  onClick?:  () => void;
}

export function ToolbarButton({ icon, label, active, disabled, loading, onClick }: Props) {
  return (
    <button
      title={label}
      disabled={disabled || loading}
      onClick={onClick}
      className={clsx(
        'flex items-center justify-center w-8 h-8 rounded',
        'transition-colors duration-100',
        'disabled:opacity-40 disabled:cursor-not-allowed',
        active
          ? 'bg-accent text-accent-foreground'
          : 'hover:bg-muted text-foreground',
      )}
    >
      {loading ? <Loader2 size={16} className="animate-spin" /> : icon}
    </button>
  );
}
