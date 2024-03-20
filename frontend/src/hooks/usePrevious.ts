import { useEffect, useRef } from "react";

function usePrevious(value: any) {
  const ref = useRef<typeof value>();
  useEffect(() => {
    ref.current = value;
  }, [value]);
  return ref.current;
}

export default usePrevious;
