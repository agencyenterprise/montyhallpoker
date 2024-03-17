import { useEffect, useRef } from 'react';

export function usePollingEffect(callback: (...arg: unknown[]) => Promise<void>, dependencies = [], options: { interval: number; stop: boolean; controller?: AbortController } = { interval: 3000, stop: false }) {
    const timeoutRef = useRef<NodeJS.Timeout | null>(null)
    const { interval, stop, controller } = options

    useEffect(() => {
        if (stop) {
            controller!.abort()
            clearTimeout(timeoutRef.current!)
            return;
        }
        ; (async function pollingFn() {
            try {
                await callback()
            } finally {
                timeoutRef.current = setTimeout(pollingFn, options.interval)
            }
        })()
        return () => clearTimeout(timeoutRef.current!)
    }, [...dependencies, interval, stop])
}
