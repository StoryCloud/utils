defmodule Utils.Box do
  defdelegate ensure_folder(name, parent_id), to: __MODULE__.File

  defdelegate ensure_file(path, name, parent_id), to: __MODULE__.File

  defdelegate set_metadata(file_id, meta), to: __MODULE__.File
end
