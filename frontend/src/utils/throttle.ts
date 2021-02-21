/**
 * Returns a throttled function that can only be called once per timeMs.
 * After not being called for timeMs, the first function call will execute immediately.
 * The last invocation will always execute after timeMs. Any throttled invocations before then will be dropped.
 * 
 * @param func The function to throttle.
 * @param timeMs `func` can only be called once per `timeMs`.
 */
export default function throttle<T extends any[]>(func: (...params: T) => void, timeMs: number): (...params: T) => void {
    let timeout: number | null = null;
    let lastExecution: number = 0;

    return function() {
        if (timeout !== null) {
            clearTimeout(timeout);
        }

        timeout = setTimeout(() => {
            func.apply(arguments);
            lastExecution = Date.now();
            timeout = null;
        }, Math.max(timeMs - (Date.now() - lastExecution), 0)) as unknown as number;
    }
}