# VieNeu-TTS Utils Module
# This module provides utility functions for text processing and phonemization

from utils.core_utils import split_text_into_chunks
from utils.normalize_text import VietnameseTTSNormalizer
from utils.phonemize_text import (
    phonemize_text,
    phonemize_with_dict,
    load_phoneme_dict,
    setup_espeak_library,
    PHONEME_DICT_PATH
)

__all__ = [
    "split_text_into_chunks",
    "VietnameseTTSNormalizer",
    "phonemize_text",
    "phonemize_with_dict",
    "load_phoneme_dict",
    "setup_espeak_library",
    "PHONEME_DICT_PATH",
]
