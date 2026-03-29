class TaskFile:
    def __init__(self, original_name: str, name: str, content: bytes):
        self.original_name = original_name
        self.name = name
        self.content = content
