require 'puppet/util/windows'
require 'ffi'

class Puppet::Util::Windows::EventLog
  extend FFI::Library

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363679(v=vs.85).aspx
  EVENTLOG_ERROR_TYPE       = 0x0001
  EVENTLOG_WARNING_TYPE     = 0x0002
  EVENTLOG_INFORMATION_TYPE = 0x0004

  # Register an event log handle for the application
  # @param source_name [String] the name of the event source to retrieve a handle for
  # @return [void]
  # @api public
  def initialize(source_name = 'Puppet')
    @eventlog_handle = RegisterEventSourceW(nil, Puppet::Util::Windows::String.wide_string(source_name))
    if @eventlog_handle == FFI::Pointer::NULL_HANDLE
      raise Puppet::Util::Windows::Error.new("failed to open Windows eventlog")
    end
  end

  # Close this instance's event log handle
  # @return [void]
  def close
    result_of_close = DeregisterEventSource(@eventlog_handle)
    if result_of_close == FFI::WIN32_FALSE
      raise Puppet::Util::Windows::Error.new("failed to close Windows eventlog")
    end
    @eventlog_handle = nil
  end

  # Report an event to this instance's event log handle. Accepts a string to
  #   report (:data => <string>) and event type (:event_type => FixNum) and id
  # (:event_id => FixNum) as returned by #to_native. The additional arguments to
  # ReportEventW seen in this method aren't exposed - though ReportEventW
  # technically can accept multiple strings as well as raw binary data to log,
  # we accept a single string from Puppet::Util::Log
  #
  # @param args [Hash{Symbol=>Object}] options to the associated log event
  # @return [void]
  def report_event(args = {})
    raise ArgumentError, "data must be a string, not #{args[:data].class}" unless args[:data].is_a?(String)
    FFI::MemoryPointer.from_string_to_wide_string(args[:data]) do |message_ptr|
      FFI::MemoryPointer.new(:pointer, 2) do |message|
        message[0].write_pointer(message_ptr)
        user_sid, raw_data = nil
        raw_data_size = 0
        num_strings = 1
        eventlog_category = 0
        report_result = ReportEventW(@eventlog_handle, args[:event_type],
          eventlog_category, args[:event_id], user_sid,
          num_strings, raw_data_size, message, raw_data)

        if report_result == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new("failed to report event to Windows eventlog")
        end
      end
    end
  end

  class << self
    # Feels more natural to do Puppet::Util::Window::EventLog.open("MyApplication")
    alias :open :new

    # Query event identifier info for a given log level
    # @param level [Symbol] an event log level
    # @return [Array] Win API Event ID, Puppet Event ID
    def to_native(level)
      case level
      when :debug,:info,:notice
        [EVENTLOG_INFORMATION_TYPE, 0x01]
      when :warning
        [EVENTLOG_WARNING_TYPE, 0x02]
      when :err,:alert,:emerg,:crit
        [EVENTLOG_ERROR_TYPE, 0x03]
      else
        raise ArgumentError, "Invalid log level #{level}"
      end
    end
  end

  ffi_convention :stdcall

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363678(v=vs.85).aspx
  # HANDLE RegisterEventSource(
  # _In_ LPCTSTR lpUNCServerName,
  # _In_ LPCTSTR lpSourceName
  # );
  ffi_lib :advapi32
  attach_function_private :RegisterEventSourceW, [:lpwstr, :lpwstr], :handle

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363642(v=vs.85).aspx
  # BOOL DeregisterEventSource(
  # _Inout_ HANDLE hEventLog
  # );
  ffi_lib :advapi32
  attach_function_private :DeregisterEventSource, [:handle], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363679(v=vs.85).aspx
  # BOOL ReportEvent(
  #   _In_ HANDLE  hEventLog,
  #   _In_ WORD    wType,
  #   _In_ WORD    wCategory,
  #   _In_ DWORD   dwEventID,
  #   _In_ PSID    lpUserSid,
  #   _In_ WORD    wNumStrings,
  #   _In_ DWORD   dwDataSize,
  #   _In_ LPCTSTR *lpStrings,
  #   _In_ LPVOID  lpRawData
  # );
  ffi_lib :advapi32
  attach_function_private :ReportEventW, [:handle, :word, :word, :dword, :pointer, :word, :dword, :lpwstr, :lpvoid], :win32_bool
end
