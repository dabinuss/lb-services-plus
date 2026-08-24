import { useEffect, useState } from 'react'

export function useMinuteTick() {
  const [, setTick] = useState(0)
  useEffect(() => {
    const timer = window.setInterval(() => setTick((value) => value + 1), 60000)
    return () => window.clearInterval(timer)
  }, [])
}
