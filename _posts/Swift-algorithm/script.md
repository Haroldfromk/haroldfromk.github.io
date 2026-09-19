Okay, so let's create a new project.

Now I would like to create a multi-platform app.

Click next.

And this is going to be focusing on doubly linked lists.

And we can include tests here and let's press next.

So include test plays next.

Save it.

So we're going to present, um, a generic data structure for doubly linked lists.

Before we do that in our folders up here, I'm going to create two groups.

So the first group will be just views and we'll create yet another group.

We shall be called algorithms In general, displaying these data structures is not so easy.

But we're going to do this.

Okay, We're going to do this now.

Before we continue, I want us to be in portrait mode.

So I'm going to click in this area up here and.

Um, actually, no, not portrait.

I want us to be in landscape.

So let's focus on landscape.

And now let's go back to the algorithms folder and create a new swift file.

So algorithms and command n swift file.

So let's call this doubly.

Linked list node.

And I'm going to create another file.

Command n a new swift file called doubly linked list.

So now let's jump back to the doubly linked list node and create a typical node.

Now we are going to want to reference other nodes and structs are not.

They cannot reference themselves.

So.

We have class doubly linked list node and I want this to have a generic parameter.

Now it'll have a value of type T and we'll have a pointer to the previous node.

With Typekit and the next node.

Oh, and why does it say value task?

Value is of type T?

And the class has no initializers so let's create an init.

So init.

And let's do value T.

Self dot value.

Equals to value.

And actually, I want the previous and next nodes to be optional.

And that's it.

We have our doubly linked list node.

By default, these will be set to nil.

And we're good.

So in the next video, we'll move on to the more interesting data structure of a doubly linked list.

So this you can imagine as just links and arrows in two directions.

So I can show you this.

So it'll look something like this.

Eventually we'll build something that looks like this.

So you have these values.

This is at the head of the list.

I didn't write that.

But we can add the word head.

And the tail is at the very end of the list.

And this is bi directional.

Okay.

And in general, you know, operations that we're interested is searching for an element, removing

an element, inserting an element.

Those are usually the operations that we care for.

So in general, we'll be quite difficult to create these drawings, but we will implement this in,

in this, uh, in the next few videos.

Okay, great.

So have an amazing day and see you next time.

---

class DoublyLinkedListNode<T> {
    var value: T
    var prev: DoublyLinkedListNode<T>?
    var next: DoublyLinkedListNode<T>?
    
    init(value: T) {
        self.value = value
    }
}

---

Okay, So let's jump to the doubly linked list.

And we don't have anything here, so let's create a new class.

Class double a.

Linked list.

And this should be.

This should be generic.

And this list will have a head, which will be a doubly linked list node and it will have a tail.

And let's create an init.

So this is our default in it.

And I also wanted to give it I want to have some default values so we'll have equal to nil by default

and.

And I want this to be optional, actually, because they could be nil and this will also be nil by default.

And I also want to define.

And yeah, let's make sure this is just optional.

I also want to define an append function.

So let's create a function.

Append value of type T, t could be an int, a string, whatever.

And now let's create a new node.

So let new node be equal to a doubly linked list node with value value.

Now, if the head is nil, then we'll set the head to the new node.

And the same goes for the tail.

Otherwise.

Let's set the tail.

The next pointer of the tail to be new node.

And this is optional.

So let's fix this.

So if this is nil, this line just won't happen.

And new node dot previous.

Let's set it to tail.

And now the tail can be the new node.

So that will append.

So the tail is like the end of the list.

Okay.

And we want new nodes to be the new end of the list.

So the previous node of new node should point to the tail.

Okay.

And next value should point to new node.

Assuming tail is not nil.

Okay.

So that's roughly the logic.

And let's also have now that we have a append, it would be nice if we could have yet another init that

just accepts a bunch of values like an array of type T.

T could be int or string or whatever.

And then just like we did before, we can set well, we can set set health self dot head to nil.

Self dot tail also to nil.

And next let's do for value in values.

Self dot append.

Value.

Now, the logic here could be true.

You know, it could be bad, it could be good.

But we're going to be testing out this code.

Okay.

We're going to be testing out this code.

So this just depends.

Values one at a time.

So I can just enter a bunch of values into our linked list.

Okay, So we'll be testing this soon and we'll also be creating, excuse me, a nice UI for this.

So we're going to have to create some some views.

And we'll be doing that in the next lectures.

So have an amazing day and see you next time.

---

class DoublyLinkedList<T> {
    var head: DoublyLinkedListNode<T>?
    var tail: DoublyLinkedListNode<T>?
    
    init(head: DoublyLinkedListNode<T>? = nil, tail: DoublyLinkedListNode<T>? = nil) {
        self.head = head
        self.tail = tail
    }
    
    init(values: [T]) {
        self.head = nil
        self.tail = nil
        for value in values {
            self.append(value: value)
        }
    }
    
    func append(value: T) {
        let newNode = DoublyLinkedListNode(value: value)
        if head == nil {
            head = newNode
            tail = newNode
        } else {
            tail?.next = newNode
            newNode.prev = tail
            tail = newNode
        }
    }
    
    
}

---

Okay, so let's start creating some views.

So I'm going to go to the Views folder, press Command N, Let's create a new Swiftui view.

And I'm just going to call this say node node view.

So we have our node view.

Just organize things a little bit and.

I want this to be generic.

So we'll have this T over here.

And now we want a value of type T, and I want a font.

And say, let's let it be body, but maybe we'll change it later.

Oh, didn't press new line.

Excuse me.

And I want a private state variable.

Selected.

Maybe we'll want to be able to select the nodes.

I'm giving us this possibility.

Let's set it to false for now.

And it's kind of upset.

So let's fix this control option.

Command F.

The value is not task.

Value is t.

And now let's see an example.

Friends, for instance, the value three.

And I'm going to put this actually in a vstack So we'll see some more examples.

Okay, great.

But now let's start implementing this.

So let's let's start as follows.

I'm going to create an H stack.

And first of all, let's do text quotes.

Actually, I think I'll create a few spaces, but again, we might change this.

Next, let's have text.

And let's have string describing.

Describing our value.

With a font of title.

And let's add a little padding now also.

Okay.

And I want a color.

So let's just go back up here.

Oh, and by the way, I need to make sure I'm on iPhone 13 Mini.

I didn't notice that.

I'm not on that.

Okay, So now up here, I want to create a computed property called color.

And if.

It's selected choose color dot read with opacity 0.7 otherwise.

So colon, let's do color dot blue.

Okay, so if we're selected, it'll be red.

If we're not selected, it'll be blue.

Currently we are not selected.

We haven't used this color.

So let's apply this color.

So let's apply this color to the text.

So the background.

Will be just color.

And I'm going to duplicate this text over here.

And for the first piece of text with spaces, I'm going to add padding that vertical and padding that

leading of five.

We'll see the effect soon.

And I'm going to do the same thing down below.

But instead of dot leading, we'll use that trailing.

Okay, great.

Now, right after the stack, I'd like to clip this with a rounded rectangle.

So I'm going to fold the stack.

To make sure that I don't miss.

So let's use a clip shape rounded rectangle with a corner radius of ten.

And an overlay.

With same type of rounded rectangle.

But it should be a stroke, right?

Everything just disappeared.

So let's make sure we add that stroke.

And finally, let's add some padding, which is that vertical.

And the font.

I want it to be font.

And on tap gesture with animation.

Selected that toggle.

So if I.

Click on this.

Okay, so toggles.

And let's just go to this text.

So let spaces equal to the spaces over here.

So I'm going to replace these spaces with the word spaces also down over here.

And now let's reduce the number of spaces.

Let's do that again.

Okay.

And let's see a few more examples.

So if we go all the way down to our V stack and duplicate the node view, then instead of the number

three, I can use the word tree, for instance.

And we can also create like a tuple, right?

A tuple with a value of, say, -17 comma five, comma.

Hello.

Okay, so these are all examples of nodes and yeah, it looks pretty cool.

So we'll be connecting these nodes in the next lecture.

So have an amazing day and see you next time.

---

//
//  NodeView.swift
//  DoublyLinked
//
//  Created by Dongik Song on 9/19/26.
//

import SwiftUI

struct NodeView<T>: View {
    let value: T
    let font: Font = .body
    @State private var selected: Bool = false
    
    var color: Color {
        selected ? Color.red.opacity(0.7) : Color.blue.opacity(0.7)
    }
    
    let spaces = "  "
    
    var body: some View {
        HStack {
            Text(spaces)
                .padding(.vertical)
                .padding(.leading, 5)
            
            Text(String(describing: value))
                .font(.title)
                .padding()
                .background(color)
            
            Text(spaces)
                .padding(.vertical)
                .padding(.trailing, 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke())
        .padding(.vertical)
        .font(font)
        .onTapGesture {
            withAnimation {
                selected.toggle()
            }
        }

    }
}

#Preview {
    NodeView(value: 3)
    NodeView(value: "Tree")
    NodeView(value: (17,5,"Hello"))
}

---

Okay.

So in addition, I would like a view that will just be a null view.

So I'm going to call this null view.

And this view will actually be quite simple.

It will display the word null.

Okay.

So I'm going to use font dot headline.

Now, obviously I did some trial and error here.

And let's let it be bold with a foreground color of that blue.

And let's add a little padding.

And finally, let's overlay it.

With a rounded rectangle of corner radius ten.

And let's just make sure that we stroke the rounded rectangle because by default, it's a fill and we

have our null view.

Okay, Now, I don't want too many things in one video, so let's take a break now.

And in the next video, we'll really do the doubly linked list view.

Okay, great.

So have an amazing day and see you next time.

---

struct NullView: View {
    var body: some View {
        Text("Null")
            .font(.headline)
            .bold()
            .foregroundStyle(.blue)
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 10).stroke())
    }
}

#Preview {
    NullView()
}


---

Okay, so now we'd like to have a.

Linked list view.

So make sure you're in the views folder Command n swiftui view.

And let's call this doubly linked list view.

And we're going to have a generic parameter here.

And let's let doubly linked lists be of type doubly linked list with a T.

So this is generic and let arrow equal to zero dot left .0. right.

And the spelling is crucial and let.

Let distance.

Be -5.0.

Now, down here, let's fix this.

So actually, let's have.

Our argument.

I'm going to get rid of the Annie.

And let's have the following doubly linked list with values from the array, negative three comma 7

to 14, 17 three periods, negative three, 7 to 14, 17.

Three and 15.

Okay now.

Okay, so now let's get to work.

So first of all, I'm going to create a scroll view.

With horizontal axis and show indicators set to false.

In addition, let's have an H stack.

With zero spacing.

And first, let's have our null view.

I didn't use squiggly braces.

Null view set another view.

Null view.

And in the middle.

In the middle we're going to have an H stack with spacing equal to distance.

And now I'd like to have an image system named Arrow with a font of large title and a font weight.

Font weight of that thin.

It's starting to look like something not quite what we want.

So obviously the whole middle part is missing and we're going to have a for each year.

So.

We're going to have a for each that will display the nodes in the middle.

Now we're going to want a function called get nodes node values.

So to do that, we'll have to do two things.

First of all.

I'd like us to go back to doubly linked list node and let's make sure this conforms to identifiable.

That's the first thing.

It's a minor thing.

But for the for each we're going to need this.

So let this conform to identifiable.

Next let's go to doubly linked list and let's add a new function.

So some of the code over here just so it'll be a little bit easier to view.

So let's create a function, get node values which will return an array of type, doubly linked list

nodes.

So it'll return a bunch of nodes.

So let's set values of type double doubly linked list node t to be the empty list and we'll gradually

add things to the list.

Now let's set the current value to self dot head.

We don't really need the word self, so while current is not equal to nil, then just proceed.

Right?

So first of all, values let's append.

So append init value current value.

Now current is not nil.

So I could force unwrap here.

Usually I don't like doing that, but I did this time because we just checked a moment ago.

And next, let's proceed.

So current should be equal to current dot next.

And it automatically added this question mark over here.

So I'm just going to run through the list going through the next five each time and appending the value

at the next spot.

Okay.

And finally, we need to return the values so we can use this to get the node values.

For our, um.

For our view.

Okay.

So I'm going to go back to doubly linked list view.

And now let's have a for each.

So let's use doubly linked list dot get node values and we should have a question mark over here.

But also this is optional.

So we're going to have to use some nil coalescing.

So I'm using nil, coalescing and having just an empty set here.

And actually, maybe we don't really need this.

I think.

I don't know why I added that.

Okay, great.

And finally let's say node in.

And now double.

Well, excuse me.

Not whole node view with a value of node dot value.

Notice we suddenly have everything, right?

This is looking a lot better, but we don't have the arrows, right?

So I'm just going to grab this arrow right here and duplicate this.

And it would be interesting to note what would happen if we remove this.

Okay.

We have a little warning here.

Oh, okay.

We can actually drop that.

Yeah, we're good.

So all this nail collecting was not necessary.

And this looks quite nice.

The only thing that we could maybe add is some spacing to the to the stack.

And we should preview this rotated.

Of course, the whole idea was that this would be in landscape view.

So I'm going to go up here, hold the scroll view, add padding, let's run this.

And we have Hello World because we never called a doubly linked list view, right?

So let's go to the app entry point here and let's comment out, comment, view and let's have doubly

linked list view.

Or let's do this differently, actually.

What I'll do is the following.

Let's go back to doubly linked list view.

Let's grab this example.

This this example in our preview and let's just put it in the content view.

Okay.

So let's add a little title.

Doubly linked list can hide this.

Add this, run it and maybe we want to do some cosmetics here to make it look a little bit nicer.

But we have something kind of nice.

Okay?

And we can click this and we would like to develop this further.

Right.

But this already looks, you know, impressive in my opinion.

And of course we can.

Add font, say large title or title and let's let this the font weight be semi bold and run this again.

Yeah.

Looks looks very nice.

Looks very nice.

Quite impressive.

And later maybe we'll you know, implement tap gesture or long tap gesture to delete and so on.

Okay great.

So have an amazing day and see you next time.

---

class DoublyLinkedListNode<T>: Identifiable {
    var value: T
    var prev: DoublyLinkedListNode<T>?
    var next: DoublyLinkedListNode<T>?
    
    init(value: T) {
        self.value = value
    }
}

func getNodeValues() -> [DoublyLinkedListNode<T>] {
        var values: [DoublyLinkedListNode<T>] = []
        var current = self.head
        while current != nil {
            values.append(.init(value: current!.value))
            current = current?.next
        }
        
        return values
     }

struct DoublyLinkedListView<T>: View {
    let doublyLinkedList: DoublyLinkedList<T>
    
    let arrow = "arrow.left.arrow.right"
    let distance = -5.0
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                NullView()
                
                HStack(spacing: distance) {
                    Image(systemName: arrow)
                        .font(.largeTitle)
                        .fontWeight(.thin)
                    
                    ForEach(doublyLinkedList.getNodeValues()) { node in
                        NodeView(value: node.value)
                        Image(systemName: arrow)
                            .font(.largeTitle)
                            .fontWeight(.thin)
                    }
                    
                }
                
                NullView()
                
            }
        }
        .padding()
    }
}

#Preview {
    DoublyLinkedListView(doublyLinkedList: DoublyLinkedList(values: [-3, 7, 2, 14, 3, 50]))
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Doubly Linked List")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            DoublyLinkedListView(doublyLinkedList: DoublyLinkedList(values: [-3, 7, 2, 14, 3, 50]))
            
        }
        .padding()
    }
}

---

Okay, so we would like to implement some delete functionality, but there's no way to do this if we

are too generic.

So I'd like us to go to the doubly linked list class and let's make this conform to equatable.

Now we'll have to do that in other places too, for, for instance, in the doubly linked list node.

So if we jump to the node, we should also make this equatable.

And also in our generic view, we should make those changes.

So let's press command B and we have an issue because of our view.

So let's click on the arrow.

So doubly linked list view, there seems to be a problem.

So let's jump to the doubly linked list view.

And over here this t ups appear in the view.

This is too general, so we need this to conform to equatable because we're going to be testing if two

generic values in t are equal.

Okay, great.

Now I want to implement delete functionality.

So we want to leave the view and go to the doubly linked list.

Let's fold our code.

And right below append let's create func delete.

Now we want to delete a value of what type t.

So far.

So we're just going to search for this value.

So var current.

Equals to heads.

We're starting from the beginning.

And while let node equals the current.

If no dot value equals to value, then we found it.

And we found it.

So let's store the previous node of node.

So let previous node equal to node that previous and let next node equal to node dot next.

Okay.

So we saved those pointers.

So we're pointing to the previous and next node.

And now let's update these.

Okay.

So now let's try to visualize this in a picture.

As let's look at a possible scenario.

Okay.

So we have something that looks like this.

Okay.

So this is an example.

So let's suppose I just want us to understand what we're doing, right?

So let's suppose that the value.

Let's suppose the value.

Is equal to seven.

Okay.

So that means that this is Node over here.

And that means that previous node prev node.

Is just equal to this node.

And next node.

Excuse my handwriting is equal to this.

Okay.

Now what do we want?

We want to get rid of this.

And how can we get rid of this?

Well, we're just basically going to ignore this.

So this arrow over here should link to here.

So that means, Oh, I just made a mistake.

I swapped between next node and previous node.

It's kind of embarrassing.

This is previous, and this is next.

So this means that.

Previous node.

That next should be equal to what should be equal to next node if possible.

Okay.

It might not be possible because maybe this is nil, right?

What if this is maybe this is null or nil?

I wrote null nil.

And so we'll address that.

And in addition, the next node should no longer point to this, right?

The next node should be pointing over here.

Right?

So that means we want next node dot previous equals to previous node.

So that's the idea here.

Now this is optional.

So there's going to be a little issue here, but we'll take care of that.

So we have, we'd like to say previous node dot next equals to next node.

And notice that this is optional, this might not take place and we want next node dot previous equals

to previous node.

Now, we do have some extreme cases, right?

Right.

We have the case where the node equals to the head and we have the case where the node equals to the

tip.

So let's try to go back to our picture.

Well, let's actually change it to this so that they're actually truly equal.

Okay, But suppose we have a different situation where the value is actually equal to the head.

Then let's see what we want.

So we want to get rid of this, right?

We want to get rid of the head.

So that means we need to update it, right?

So the head should now become the next node.

Likewise, the tail.

If the node is equal to the tail, then the tail should become the previous node and these might be

nil values, but that's that's okay.

So that means that head equals to next node and tail.

If the node is equal to the tail, then it's equal to the previous node.

Now, if we successfully enter this if statement over here, then at this point over here, we want

to leave the function.

So just return.

And.

This is a little bit confusing.

So let's fold this if statement.

I want to still be in the wild and we need to.

Okay.

So in this this iteration, we did not find no dot value equals to value.

So move on to next note.

So that means that current equals to next.

Uh, node dot next.

Okay.

And we should.

We should test this out.

So be wise to write tests.

Unit tests for a linked list.

Okay.

So try implementing it in the view, but better yet, try to implement a unit test that creates a linked

list.

Deletes values.

Um, we can always get node values, right.

So you could create a test that constructs a list with the numbers two, three and five.

Ask it to delete the number two.

And see if the notes that you get are just three and five.

Okay, great.

So have an amazing day and see you next time.

---

class DoublyLinkedListNode<T: Equatable>: Identifiable {
    var value: T
    var prev: DoublyLinkedListNode<T>?
    var next: DoublyLinkedListNode<T>?
    
    init(value: T) {
        self.value = value
    }
}

struct DoublyLinkedListView<T: Equatable>: View {
    // 생략
}

class DoublyLinkedList<T: Equatable> {
    // 생략
}

    func delete(value: T) {
        var current = head
        
        while let node = current {
            if node.value == value {
                let prevNode = node.prev
                let nextNode = node.next
                
                prevNode?.next = nextNode
                nextNode?.prev = prevNode
                
                if node === head {
                    head = nextNode
                }
                
                if node === tail {
                    tail = prevNode
                }
                
                return
            }
            
            // Move on to next node
            current = node.next
        }
    }