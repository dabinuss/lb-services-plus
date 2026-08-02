export interface GalleryItem { src: string; }

declare global {
  interface Window {
    components?: {
      setGallery: (options: {
        includeVideos: boolean;
        includeImages: boolean;
        allowExternal: boolean;
        multiSelect: boolean;
        onSelect: (data: GalleryItem | GalleryItem[]) => void;
      }) => void;
      setFullscreenImage?: (src: string) => void;
    };
  }
}

export function openMediaPicker(onSelect: (urls: string[]) => void) {
  if (!window.components?.setGallery) {
    onSelect(["https://images.unsplash.com/photo-1515569067071-ec3b51335dd0?auto=format&fit=crop&w=900&q=80"]);
    return;
  }
  window.components.setGallery({
    includeVideos: true,
    includeImages: true,
    allowExternal: true,
    multiSelect: true,
    onSelect: (data) => {
      const selected = (Array.isArray(data) ? data : [data]).map((item) => item.src).filter(Boolean).slice(0, 4);
      if (selected.length) onSelect(selected);
    }
  });
}

export function openFullscreenMedia(src: string) {
  if (window.components?.setFullscreenImage) window.components.setFullscreenImage(src);
  else window.open(src, "_blank", "noopener,noreferrer");
}
