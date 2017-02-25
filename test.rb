# Test Geo2D using graphics

require 'rubygems'
require 'bundler/setup'

require 'geo2d'
require 'graphics'

class Numeric
  def sign
    self<=>0
  end
end

class Test <  Graphics::Simulation

  def initialize(title: 'Test', width: 600, height: 600)
    super width, height, 24
    reset
    @draw = false
  end

  def reset
    @line = Geo2D::Line(Geo2D::Point(100,100), Geo2D::Point(150,150))
    @l = 0.0
    @d = 20.0
    @rot = 0
    @rt = []
    @lt = []
  end

  def handle_event(event, n)
    case event
    # when SDL::Event::Mousemove
    #   puts "move #{event.x} #{h-event.y} = #{mouse[0]} #{mouse[1]}"
    when SDL::Event::Mousedown
      @levent =  "MDOWN #{event.x} #{h-event.y} = #{mouse[0]} #{mouse[1]}"
      # @line << mouse[0..1]
      @draw = true
    when SDL::Event::Mouseup
      @levent = "MUP #{mouse[0]} #{mouse[1]}"
      @draw = false
    # when SDL::Event::Keydown
    #   @levent = "KEY #{Time.now}"
    #   reset
    end
    super
  end

  def initialize_keys
    super
    add_keydown_handler(" "){ reset }
    add_keydown_handler("q"){ exit }
  end

  # draw rotated text txt at x, y with angle
  # if a color is assigned to parameter box a bounding box is drawn
  def rotated_text(txt, x:, y:, angle: 0, mode: :center, tfont: font, color: :black, box: false, halign: :center, valign: :center)
    angle_r = angle*Math::PI/180
    img = render_text(txt, color, tfont)
    tw = img.w*Math.cos(angle_r).abs + img.h*Math.sin(angle_r).abs
    th = img.h*Math.cos(angle_r).abs + img.w*Math.sin(angle_r).abs

    case halign
    when :left
      xd = 0
    when :right
      xd = -tw
    when :center
      xd = -tw/2
    end

    case valign
    when :top
      yd = -th
    when :bottom
      yd = 0
    when :center
      yd = -th/2
    end

    rect x+xd,y+yd, tw, th, box if box
    put img, x+xd, y+yd, angle
  end

  def horizontal_text(txt, x:, y:, halign: :left, valign: :bottom, tfont: font, color: :black)
    # this is equivalent to:
    #   rotated_text(txt, x: x, y: y, halign: halign, valign: valign, tfont: tfont, color: color)

    # tw, th = text_size(txt, tfont) # seems broken in 1.0.0b6
    img = render_text(txt, color, tfont)
    tw = img.w
    th = img.h

    case halign
    when :left
      xd = 0
    when :right
      xd = -tw
    when :center
      xd = -tw/2
    end

    case valign
    when :top
      yd = -th
    when :bottom
      yd = 0
    when :center
      yd = -th/2
    end

    text txt, x+xd, y+yd, color, tfont
  end

  # quadrant (0-3) of an angle
  def quadrant(angle_rad, offset: 0.0)
    k = 4.0
    angle_rad = (angle_rad + offset) % (2*Math::PI)
    ((angle_rad * k/(2*Math::PI)).floor) % k
  end

  def horizontal_label(txt, x:, y:, lead_angle:, color: black, tfont: font)
    q = quadrant(lead_angle, offset: Math::PI/4)
    case q
    when 0
      halign = :left
      valign = :center
    when 1
      halign = :center
      valign = :bottom
    when 2
      halign = :right
      valign = :center
    else # when 3
      halign = :center
      valign = :top
    end
    horizontal_text txt, x: x, y: y, tfont: tfont, color: color, valign: valign, halign: halign
  end

  def draw(t)
    mouse_x, mouse_y, * = mouse
    @line << [mouse_x, mouse_y] if @draw

    # erase surface
    rect 0, 0, w, h, CLEAR_COLOR, true

    # draw whole path
    for i in 1...@line.n_points
      line *@line.points[i-1].split, *@line.points[i].split, :red
    end

    # draw right trail
    for i in 1...@rt.size
      line *@rt[i-1].split, *@rt[i].split, :white
    end

    # draw left trail
    for i in 1...@lt.size
      line *@lt[i-1].split, *@lt[i].split, :yellow
    end

    advance_position

    r1 = r2 = @rot

    # left point
    lp = @line.interpolate_point(@l, @d, r1)
    @lt << lp
    ellipse lp.x, lp.y, 10, 10, :yellow, true

    # center point
    p = @line.interpolate_point(@l)
    ellipse p.x, p.y, 6, 6, :blue, true

    # right point
    rp = @line.interpolate_point(@l, -@d, r2)
    @rt << rp
    ellipse rp.x, rp.y, 10, 10, :white, true

    @rt.shift if @rt.size > 20
    @lt.shift if @lt.size > 20

    # right label point
    rlp = @line.interpolate_point(@l,-@d*1.7,r2)
    lead_angle = (rlp - p).argument # or (rlp - rp).argument
    horizontal_label 'right', x: rlp.x, y: rlp.y, lead_angle: lead_angle, color: :white

    # left label point
    llp = @line.interpolate_point(@l,@d*2.5,r1)
    # ellipse llp.x, llp.y, 4, 4, :gray, true
    rotated_text 'left',  x: llp.x, y: llp.y, angle: (@angle + r1)*180/Math::PI, color: :yellow
  end

  # Advance the current position in the path, computing @rot, @l, @angle
  def advance_position
    inc = @d<0 ? -6.0 : +6.0
    angle = (a2=@line.angle_at(@l+inc))-(a1=@line.angle_at(@l))
    if angle.abs > Math::PI
      angle -= angle>0 ? 2*Math::PI : -2*Math::PI
    end
    if angle.abs > [@rot.abs,0.8].max && angle.abs<Math::PI
      @rot -= angle < 0 ? +0.2 : -0.2
      angle = a1 # + @rot
    else
      @l += inc
      @rot = 0
      angle = a2
    end
    if @l>=@line.length
      if @line.points.last.distance_to(@line.points.first)<4.0
        @l = 0
      else
        @l = @line.length
        @d = -@d
      end
      @rot = 0
    elsif @l<=0
      if @line.points.last.distance_to(@line.points.first)<4.0
        @l = @line.length
      else
        @l = 0.0
        @d = -@d
      end
      @rot = 0
    end
    @angle = angle
  end
end

Test.new(title: 'Test', width: 800, height: 600).run
