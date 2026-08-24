import { useCallback, useEffect, useRef, useState } from 'react'

import { appendUnique, listCursor, mergeNewestPage } from './lists.js'
import { fetchNui } from './nui.js'

export function useCursorList(action, {
  key = 'id', time = 'cursor_time', open = false, pageSize = 25,
  refreshToken = null, removedId = null,
} = {}) {
  const [items, setItems] = useState(null)
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [error, setError] = useState(false)
  const olderLock = useRef(false)
  const seenRefresh = useRef(refreshToken)
  const cursorRef = useRef(null)

  const loadNewest = useCallback(async (replace = true, refreshRemovedId = null) => {
    try {
      const result = await fetchNui(action, {})
      if (!Array.isArray(result)) {
        if (replace) setItems([])
        setError(true)
        return false
      }
      setError(false)
      setItems((current) => replace ? result : mergeNewestPage(current, result, key, refreshRemovedId))
      if (replace) {
        cursorRef.current = listCursor(result, { id: key, time, open })
        setHasMore(result.length === pageSize)
      }
      return true
    } catch {
      if (replace) setItems([])
      setError(true)
      return false
    }
  }, [action, key, open, pageSize, time])

  useEffect(() => { loadNewest() }, [loadNewest])

  useEffect(() => {
    if (refreshToken == null || refreshToken === seenRefresh.current) return
    seenRefresh.current = refreshToken
    loadNewest(false, removedId)
  }, [refreshToken, removedId, loadNewest])

  const loadMore = useCallback(async () => {
    if (olderLock.current || !hasMore) return
    const cursor = cursorRef.current || listCursor(items, { id: key, time, open })
    if (!cursor) return

    olderLock.current = true
    setLoadingMore(true)
    try {
      const result = await fetchNui(action, { cursor })
      if (!Array.isArray(result)) {
        setError(true)
        return
      }
      setError(false)
      setItems((current) => appendUnique(current, result, key))
      cursorRef.current = listCursor(result, { id: key, time, open })
      setHasMore(result.length === pageSize)
    } catch {
      setError(true)
    } finally {
      olderLock.current = false
      setLoadingMore(false)
    }
  }, [action, hasMore, items, key, open, pageSize, time])

  return { items, setItems, hasMore, loadingMore, error, loadMore, reload: loadNewest }
}
