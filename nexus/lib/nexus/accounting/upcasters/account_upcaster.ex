defimpl Commanded.Event.Upcaster, for: Nexus.Accounting.Events.AccountOpened do
  # Standard Chapter 15: Schema Evolution
  def upcast(event, _metadata), do: event
end
