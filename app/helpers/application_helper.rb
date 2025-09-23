module ApplicationHelper
  def sentiment_color_class(score)
    case score
    when 0.3..Float::INFINITY
      'text-green-600'
    when 0.1..0.3
      'text-green-500'
    when -0.1..0.1
      'text-gray-600'
    when -0.3..-0.1
      'text-orange-500'
    else
      'text-red-600'
    end
  end

  def sentiment_gradient(score)
    case score
    when 0.2..Float::INFINITY
      'bg-gradient-to-r from-green-400 to-green-600'
    when 0.0..0.2
      'bg-gradient-to-r from-yellow-400 to-green-400'
    when -0.2..0.0
      'bg-gradient-to-r from-orange-400 to-yellow-400'
    else
      'bg-gradient-to-r from-red-400 to-orange-400'
    end
  end

  def priority_color_class(priority)
    case priority
    when 'high'
      'text-red-600'
    when 'medium'
      'text-yellow-600'
    else
      'text-green-600'
    end
  end

  def priority_description(priority)
    case priority
    when 'high'
      'Immediate action required'
    when 'medium'
      'Monitor and address concerns'
    else
      'Maintain current approach'
    end
  end

  def trend_icon(direction)
    case direction
    when 'improving'
      '📈'
    when 'declining'
      '📉'
    else
      '➡️'
    end
  end
end
