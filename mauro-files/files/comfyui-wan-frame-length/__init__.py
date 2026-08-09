class WanFrameLength:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "length": ("INT", {"default": 81, "min": 1, "max": 10000, "step": 4}),
            }
        }

    RETURN_TYPES = ("INT",)
    RETURN_NAMES = ("length",)
    FUNCTION = "get_length"
    CATEGORY = "utils/primitive"

    def get_length(self, length):
        return (length,)


NODE_CLASS_MAPPINGS = {
    "WanFrameLength": WanFrameLength,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "WanFrameLength": "Wan Frame Length (INT)",
}
