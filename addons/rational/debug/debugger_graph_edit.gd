@tool
extends GraphEdit

const RationalGraphNode := preload("../editor/graph_node.gd")
#const Style := RationalGraphNode.Style

#
#const PROGRESS_SHIFT: int = 50
const INACTIVE_COLOR: Color = RationalGraphNode.Style.NORMAL_COLOR
const ACTIVE_COLOR: Color = Color("#c29c06")
const SUCCESS_COLOR: Color = Color("#07783a")
const FAILURE_COLOR: Color = Color("#82010b")
#
#
#var horizontal_layout: bool = false:
	#set(value):
		#if horizontal_layout == value: return
		#horizontal_layout = value
			#
