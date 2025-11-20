@tool
extends ActionLeaf

class_name AlwaysSucceed

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	return SUCCESS
