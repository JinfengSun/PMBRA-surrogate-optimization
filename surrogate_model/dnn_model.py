"""DNN surrogate architecture used in the paper."""

from __future__ import annotations

import random

import numpy as np
import tensorflow as tf


def build_dnn(seed: int) -> tf.keras.Model:
    """Build the paper's deterministic 4-64-32-16-1 regression network."""
    random.seed(seed)
    np.random.seed(seed)
    tf.keras.utils.set_random_seed(seed)
    model = tf.keras.Sequential(
        [
            tf.keras.layers.Input(shape=(4,)),
            tf.keras.layers.Dense(64, activation="relu"),
            tf.keras.layers.Dense(32, activation="relu"),
            tf.keras.layers.Dense(16, activation="relu"),
            tf.keras.layers.Dense(1, activation="linear"),
        ],
        name="pmbra_dnn_surrogate",
    )
    model.compile(optimizer=tf.keras.optimizers.Adam(), loss="mse")
    return model
