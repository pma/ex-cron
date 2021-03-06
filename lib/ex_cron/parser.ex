defmodule ExCron.Parser do
  alias ExCron.Cron

  @month_names ~w(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC)
  @day_names ~w(SUN MON TUE WED THU FRI SAT)

  @moduledoc """
  Module that parses a cron string into a representation that can be used
  by code.
  """

  @doc ~S"""
  Parse a cron string into a tuple

  ## Example
      iex> ExCron.Parser.parse "0 0 1 1 *"
      {:ok, %ExCron.Cron{minutes: [0], hours: [0], days_of_month: [1], months: [1], days_of_week: [0,1,2,3,4,5,6]}}

  """
  def parse(cron) do
    case String.split cron do
      [_,_,_,_,_,_|_] -> {:error, "too many sections; 5 are required"}
      [_,_,_,_,_] = parts -> do_parse(parts)
      _ -> {:error, "not enough sections; 5 are required"}
    end
  end

  defp do_parse([minutes, hours, days_of_month, months, days_of_week]) do
    result = %Cron{
      minutes: minutes |> parse_piece(0..59),
      hours: hours |> parse_piece(0..23),
      days_of_month: days_of_month |> parse_piece(1..31),
      months: months |> parse_piece(1..12, get_name_mapper(@month_names, 1)),
      days_of_week: days_of_week |> parse_piece(0..6, get_name_mapper(@day_names))
    }

    errors = [result.minutes, result.hours, result.days_of_month, result.months, result.days_of_week]
      |> Enum.map(&has_error/1)
      |> Enum.reduce(false, fn (x, y) -> x || y end)

    case errors do
      true -> {:error, "incorrect value"}
      _ -> {:ok, result}
    end
  end

  defp has_error([]), do: true
  defp has_error(list), do: Enum.any? list, &(&1 == :error)

  defp parse_piece(piece, valid_values), do: parse_piece piece, valid_values, &Integer.parse/1
  defp parse_piece("*/" <> fractional, valid_values, _mapper) do
    fractional_value = String.to_integer fractional
    valid_values
      |> Enum.filter(&(0 == rem(&1, fractional_value)))
      |> Enum.to_list
  end
  defp parse_piece("*", valid_values, _mapper), do: valid_values |> Enum.to_list
  defp parse_piece(value, valid_values, mapper) do
    pieces = String.split value, ","
    pieces
      |> Enum.map(&(parse_piece_value(&1, mapper)))
      |> List.flatten
      |> Enum.filter(&(is_valid_section_value(&1, valid_values)))
      |> Enum.sort
  end

  defp is_valid_section_value(:error, _valid_values), do: true
  defp is_valid_section_value(value, valid_values), do: valid_values |> Enum.any?(&(value == &1))

  defp parse_piece_value(value, mapper) do
    do_parse_piece String.split(value, "-"), mapper
  end

  defp do_parse_piece([min_string, max_string], mapper) do
    with {min_value, ""} <- mapper.(min_string),
      {max_value, ""} <- mapper.(max_string),
      do: min_value..max_value |> Enum.to_list
  end

  defp do_parse_piece([string_value], mapper) do
    case mapper.(string_value) do
      {value, ""} -> value
      _ -> :error
    end
  end

  defp do_parse_piece(_, _mapper), do: :error

  defp get_name_mapper(lookup, offset \\ 0) do
    fn x ->
      upcase_x = String.upcase x
      case Enum.find_index(lookup, &(&1 == upcase_x)) do
        nil -> Integer.parse(x)
        val -> {val + offset, ""}
      end
    end
  end
end
