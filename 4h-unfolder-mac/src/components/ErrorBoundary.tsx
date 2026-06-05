import { Component, type ReactNode } from 'react';

interface Props { children: ReactNode; }
interface State { error: Error | null; }

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  render() {
    if (this.state.error) {
      return (
        <div className="flex flex-col items-center justify-center h-screen bg-background text-foreground p-8 gap-4">
          <p className="text-lg font-semibold text-destructive">Render error</p>
          <pre className="text-xs text-muted-foreground bg-muted rounded p-3 max-w-xl w-full overflow-auto">
            {this.state.error.message}
          </pre>
          <button
            className="px-4 py-2 bg-primary text-primary-foreground rounded text-sm hover:opacity-90"
            onClick={() => this.setState({ error: null })}
          >
            Dismiss
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
