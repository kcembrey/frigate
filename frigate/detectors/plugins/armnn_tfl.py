import logging
import numpy as np

from frigate.detectors.detection_api import DetectionApi
from frigate.detectors.detector_config import BaseDetectorConfig
from typing import Literal
from pydantic import Extra, Field

try:
    from tflite_runtime.interpreter import Interpreter
except ModuleNotFoundError:
    from tensorflow.lite.python.interpreter import Interpreter

logger = logging.getLogger(__name__)

DETECTOR_KEY = "armnn"


class ArmNNDetectorConfig(BaseDetectorConfig):
    type: Literal[DETECTOR_KEY]
    num_threads: int = Field(default=8, title="Number of detection threads")


def load_armnn_delegate(library_path, options=None):
    try:
        from tflite_runtime.interpreter import load_delegate
    except ModuleNotFoundError:
        from tensorflow.lite.python.interpreter import load_delegate

    if options is None:
        options = {"backends": "CpuAcc,GpuAcc,CpuRef", "logging-severity": "warning"}

    return load_delegate(library_path, options=options)


class ArmNNTfl(DetectionApi):
    type_key = DETECTOR_KEY

    def __init__(self, detector_config: ArmNNDetectorConfig):
        armnn_delegate = load_armnn_delegate("/usr/lib/ArmNN-linux-aarch64/libarmnnDelegate.so")

        self.interpreter = Interpreter(
            model_path=detector_config.model.path or "/cpu_model.tflite",
            num_threads=detector_config.num_threads or 8,
            experimental_delegates=[armnn_delegate],
        )

        self.interpreter.allocate_tensors()

        self.tensor_input_details = self.interpreter.get_input_details()
        self.tensor_output_details = self.interpreter.get_output_details()

    def detect_raw(self, tensor_input):
        self.interpreter.set_tensor(self.tensor_input_details[0]["index"], tensor_input)
        self.interpreter.invoke()

        boxes = self.interpreter.tensor(self.tensor_output_details[0]["index"])()[0]
        class_ids = self.interpreter.tensor(self.tensor_output_details[1]["index"])()[0]
        scores = self.interpreter.tensor(self.tensor_output_details[2]["index"])()[0]
        count = int(
            self.interpreter.tensor(self.tensor_output_details[3]["index"])()[0]
        )

        detections = np.zeros((20, 6), np.float32)

        for i in range(count):
            if scores[i] < 0.4 or i == 20:
                break
            detections[i] = [
                class_ids[i],
                float(scores[i]),
                boxes[i][0],
                boxes[i][1],
                boxes[i][2],
                boxes[i][3],
            ]

        return detections
